# PF2 Library

@CLASS
pfCache

## Универсальный класс кеширования.

@OPTIONS
locals

@USE
pf2/lib/common.p

@BASE
pfClass

@create[aOptions]
## Конструктор объекта
## aOptions.cacheDir[/../cache] - путь к каталогу с кэшем
  ^self.cleanMethodArgument[]
  $self._emptyTableForHash[]

  ^if(def $aOptions.cacheDir){
  	$self._cacheDir[^aOptions.cacheDir.trim[end;/]]
  }{
  	 $self._cacheDir[/../cache]
   }

@code[aKey;aTime;aCode;aErrorHandler]
## Выполняет кэширование кода. Аналог парсеровского ^cache
  $lCacheFileName[$self._cacheDir/^aKey.trim[both;/]]
  ^if(^aTime.int(-1) >= 0){
#   если в $aTime число, то кешируем на $aTime-секунд
    $result[^cache[$lCacheFileName]($aTime){$aCode}{$aErrorHandler}]
  }{
     $result[^cache[$lCacheFileName][$aTime]{$aCode}{$aErrorHandler}]
   }

@data[aKey;aTime;aType;aCode;aErrorHandler]
## Кэширует данные. Код должен возвращать только одну переменную
## Метод "знает" базовый набор классов cтрока, число, таблица, хэш, файл, дата, xdoc)
## Внимание! Если кэшируется таблица, то она должна быть именованой!
  ^self.assert(def $aKey)[Не задан ключ кеша.]
  ^try{
    $aKey[^aKey.trim[both;/]]
    ^if(!^self.isKeyFound[$aKey] || ^self.isExpired[$aKey][$aTime]){
#   если отсутствует кеш или истекло время кеширования,
#   то запускаем код и сохраняем его в кэше
      $result[$aCode]
      ^if(^aTime.int(-1) > 0){
          ^self._save[$aType][$result][$aKey]
      }{
         ^self.deleteKey[$aKey]
       }
    }{
#    иначе пытаемся взять данные из кэша
     ^try{
       $result[^self._load[$aType;$aKey]]
     }{
#     если есть проблемы с загрузкой, то выполняем код
        $exception.handled(true)
        $result[$aCode]
      }
     }
  }{
     $aErrorHandler
   }

@isKeyFound[aKey]
## Возвращает true, если ключ есть в кэше
  $result(-f "$self._cacheDir/$aKey")

@isExpired[aKey;aTime]
## Проверяет устарел ли кеш
	  $lStat[^file::stat[$self._cacheDir/$aKey]]
	  $lNow[^date::now[]]

	  ^if(^aTime.int(-1) >= 0){
#    время в секундах?
	    $result(!^aTime.int(0) || ^lNow.unix-timestamp[] - ^lStat.mdate.unix-timestamp[] > $aTime)
	  }{
#     время в виде даты?
	  	 ^if($aTime is date){
	  	 	 $lDate[$aTime]
	  	 }{
	  	 	  $lDate[^date::create[$aTime]]
	  	 	}
	  	 $result($lNow > $lDate)
		 }

@deleteKey[aKey]
## Удаляет ключ из кэша
  ^if(-f "$self._cacheDir/$aKey"){
    ^try{
    	^file:delete[$self._cacheDir/$aKey]
    }{
    	 $exception.handled(true)
     }
  }

@GET__emptyTable[]
  ^if(!def $self._emptyTableForHash){
    $self._emptyTableForHash[^table::create{key	parent	value	isHash	uid}]
  }
  $result[$self._emptyTableForHash]

@_save[aType;aValue;aKey]
## Сохраняет переменную в файл на диске
## Важно: хэш может содержать только строки.
  ^switch[$aType]{
    ^case[string;int;double]{
    		^aValue.save[$self._cacheDir/$aKey]
    }
    ^case[date]{
        $lValue[^aValue.sql-string[]]
        ^lValue.save[$self._cacheDir/$aKey]
    }
    ^case[bool]{
        $lValue[^if($aValue){1}{0}]
        ^lValue.save[$self._cacheDir/$aKey]
    }
    ^case[table]{
    	  ^aValue.save[$self._cacheDir/$aKey;$.encloser["]]
    }
    ^case[hash]{
        $aValue[^self._hash2table[$aValue]]
    	  ^aValue.save[$self._cacheDir/$aKey]
    }
    ^case[file]{
    	  ^aValue.save[binary;$self._cacheDir/$aKey]
    }
    ^case[xdoc]{
    	  ^aValue.save[$self._cacheDir/$aKey]
    }
    ^case[DEFAULT]{^throw[pfCache.data.unknown.type;Unknown data type "$aType".]}
  }

@_load[aType;aKey]
## Возвращает переменную для ключа.
## Если не указан тип или тип нам не известен, то возвращаем строку.
## Важно: таблицы могут быть только именованные.
  $lCacheFileName[$self._cacheDir/$aKey]
  ^switch[$aType]{
    ^case[string;DEFAULT]{
    	$result[^file::load[text;$lCacheFileName]]
    	$result[$result.text]
    }
    ^case[int]{
    	$result[^file::load[text;$lCacheFileName]]
    	$result(^result.text.int(0))
    }
    ^case[double]{
    	$result[^file::load[text;$lCacheFileName]]
    	$result(^result.text.double(0))
    }
    ^case[date]{
      $result[^file::load[text;$lCacheFileName]]
      $result[^date::create[$result.text]]
    }
    ^case[bool]{
      $result[^file::load[text;$lCacheFileName]]
      $result($result.text)
    }
    ^case[table]{
    	$result[^table::load[$lCacheFileName;$.encloser["]]]
    }
    ^case[hash]{
    	$result[^self._load[table;$aKey]]
      $result[^self._table2hash[$result]]
    }
    ^case[file]{
      $result[^file::load[binary;$lCacheFileName]]
    }
    ^case[xdoc]{
      $result[^xdoc::load[$lCacheFileName]]
    }
    ^case[void]{
    	$result[]
    }
  }

@_hash2table[aHash;aParent]
## Преобразует хэш строк в таблицу
## Параметр aParent передавать не нужно
  $result[^table::create[$_emptyTable]]
  ^aHash.foreach[k;v]{
 	$lUID[^math:uid64[]]
 	^if(!def $aParent){$aParent[NULL]}
  	^if($aHash.$k is hash){
  		^result.append{$k	$aParent		1	$lUID}
  		^result.join[^self._hash2table[$aHash.$k;$lUID]]
  	}{
  		 ^result.append{$k	$aParent	^taint[$v]	0	$lUID}
  	 }
  }

@_table2hash[aTable;aTree;aParent]
## Преобразует таблицу, сформированную методом _hash2table, обратно в хэш.
  ^if(!def $aTree){
    $aTree[^aTable.hash[parent][$.distinct[tables]]]
    $aParent[NULL]
  }
  $result[^hash::create[]]
  $lLevel[$aTree.[$aParent]]
  ^lLevel.menu{
    ^if($lLevel.isHash){
    	$result.[$lLevel.key][^self._table2hash[;$aTree;$lLevel.uid]]
    }{
    	 $result.[$lLevel.key][$lLevel.value]
     }
  }
