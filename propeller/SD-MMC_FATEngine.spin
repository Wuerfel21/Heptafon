{{
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// SD-MMC File Allocation Table Engine
//
// Author: Kwabena W. Agyeman
// Updated: 8/31/2011
// Designed For: P8X32A
// Version: 2.0 - Special
//
// Copyright (c) 2011 Kwabena W. Agyeman
// See end of file for terms of use.
//
// Update History:
//
// v1.0 - Original release - 1/7/2010.
// v1.1 - Updated everything. Made code abort less and caught more errors - 3/10/2010.
// v1.2 - Added support for variable pin assignments and locks - 3/12/2010.
// v1.3 - Improved code and added new features - 5/27/2010.
// v1.4 - Added card detect and write protect pin support - 7/15/2010.
// v1.5 - Improved code and increased write speed - 8/29/2010.
// v1.6 - Implemented file system pathing in all methods - 12/17/2010.
// v1.7 - Broke methods up to be more readable and made file system methods more robust - 1/1/2011.
// v1.8 - Fixed a very minor error with deleting and updated documentation - 3/4/2011.
// v1.9 - Removed all hacks from the block driver and made it faster. The block driver now follows the SD/MMC card protocol
//        exactly. Also, updated file system methods to reflect changes in the block driver - 3/10/2011.
// v2.0 - Upgraded the flush data function to also flush out file meta data when called. Also, made sure that the unmount 
//        function waits for data to be written to disk before returning and added general code enhancements - 8/31/2011.
//
// v2.0 - Special - Changed the driver to have no RTC support. The clock IO error feature has been disabled in the driver also.             
//
// For each included copy of this object only one spin interpreter should access it at a time.
//
// Nyamekye,
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Simple SPI Circuit: (Uses 6 I/O Pins)
//
//                                   3.3V
//                                    |
//                                    R 10KOHM
//                                    |
// Data Out Pin Number          ------------- SD/SDHC/SDXC/MMC data out pin - pin 7 on the card.
//
//                                   3.3V
//                                    |
//                                    R 10KOHM
//                                    |
// Clock Pin Number             ------------- SD/SDHC/SDXC/MMC card clock pin - pin 5 on the card.
//
//                                   3.3V
//                                    |
//                                    R 10KOHM
//                                    |
// Data In Pin Number           ------------- SD/SDHC/SDXC/MMC data in pin - pin 2 on the card.
//
//                                   3.3V
//                                    |
//                                    R 10KOHM
//                                    |
// Chip Select Pin Number       ------------- SD/SDHC/SDXC/MMC chip select pin - pin 1 on the card.
//
//                                   3.3V
//                                    |
//                                    R 10KOHM
//                                    |
// Write Protect Pin Number     ------------- Write Protect Pin - Connected to ground when the card is writable.
//                                                                Floats when the card is not writable.
//                                   3.3V                         The card socket should provide this pin.
//                                    |
//                                    R 10KOHM
//                                    |
// Card Detect Pin Number       ------------- Card Detect Pin - Connected to ground when the card is inserted.
//                                                              Floats when the card is not inserted.
//                                   3.3V                       The card socket should provide this pin.
//                                    |
//                                    R 10KOHM
//                                    |
//                                    ------- SD/SDHC/SDXC data 1 pin - pin 8 on the card.
//
//                                   3.3V
//                                    |
//                                    R 10KOHM
//                                    |
//                                    ------- SD/SDHC/SDXC data 2 pin - pin 9 on the card.
//
//                                   3.3V
//                                    |
//                                    ------- SD/SDHC/SDXC/MMC VDD pin - pin 4 on the card.
//
//                                    ------- SD/SDHC/SDXC/MMC VSS1 pin - pin 3 on the card.
//                                    |
//                                   GND
//
//                                    ------- SD/SDHC/SDXC/MMC VSS2 pin - pin 6 on the card.
//                                    |
//                                   GND
//
// Advanced SPI Circuit: (Uses 4 I/O Pins)
//
//                                   3.3V
//                                    |
//                                    R 10KOHM
//                                    |
// Data Out Pin Number          ------------- SD/SDHC/SDXC/MMC data out pin - pin 7 on the card.
//
//                                   3.3V
//                                    |
//                                    R 10KOHM
//                                    |
//                                    ------- Write Protect Pin - Connected to ground when the card is writable.
//                                    |                           Floats when the card is not writable.
// Write Protect Pin Number     ---   R 10KOHM                    The card socket should provide this pin.
//                                |   |
// Clock Pin Number             ------------- SD/SDHC/SDXC/MMC card clock pin - pin 5 on the card.
//
//                                   3.3V
//                                    |
//                                    R 10KOHM
//                                    |
//                                    ------- Card Detect Pin - Connected to ground when the card is inserted.
//                                    |                         Floats when the card is not inserted.
// Card Detect Pin Number       ---   R 10KOHM                  The card socket should provide this pin.
//                                |   |
// Data In Pin Number           ------------- SD/SDHC/SDXC/MMC data in pin - pin 2 on the card.
//
//                                   3.3V
//                                    |
//                                    R 10KOHM
//                                    |
// Chip Select Pin Number       ------------- SD/SDHC/SDXC/MMC chip select pin - pin 1 on the card.
//
//                                   3.3V
//                                    |
//                                    R 10KOHM
//                                    |
//                                    ------- SD/SDHC/SDXC data 1 pin - pin 8 on the card.
//
//                                   3.3V
//                                    |
//                                    R 10KOHM
//                                    |
//                                    ------- SD/SDHC/SDXC data 2 pin - pin 9 on the card.
//
//                                   3.3V
//                                    |
//                                    ------- SD/SDHC/SDXC/MMC VDD pin - pin 4 on the card.
//
//                                    ------- SD/SDHC/SDXC/MMC VSS1 pin - pin 3 on the card.
//                                    |
//                                   GND
//
//                                    ------- SD/SDHC/SDXC/MMC VSS2 pin - pin 6 on the card.
//                                    |
//                                   GND
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
}}

CON

  #1, Disk_IO_Error, Clock_IO_Error, {
    } File_System_Corrupted, File_System_Unsupported, {
    } Card_Not_Detected, Card_Write_Protected, {
    } Disk_May_Be_Full, Directory_Full, {
    } Expected_An_Entry, Expected_A_Directory, {
    } Entry_Not_Accessible, Entry_Not_Modifiable, {
    } Entry_Not_Found, Entry_Already_Exist, {
    } Directory_Link_Missing, Directory_Not_Empty, {
    } Not_A_Directory, Not_A_File

VAR long dataStructureAddress[0]

  long fileSystemType, countOfClusters, freeClusterCount, nextFreeCluster
  long currentCluster, currentSector, currentByte, currentPosition, currentSize
  long currentWorkingDirectory, currentDirectory, currentFile
  long volumeIdentification, diskSignature, hiddenSectors, totalSectors
  long FATSectorSize, rootDirectorySectorNumber, firstDataSector, dataSectors, rootCluster
  long listingCluster, listingSector, listingByte, fileDIRCluster, fileDIRSector, fileDIRByte
  word currentTime, currentDate, reservedSectorCount, rootDirectorySectors, fileSystemInfo, backupBootSector
  byte mountedUnmountedFlag, errorNumberFlag, fileOpenCloseFlag, fileReadWriteFlag, fileBlockDirtyFlag
  byte sectorsPerCluster, numberOfFATs, mediaType, activeFAT
  byte OEMName[9], fileSystemTypeString[9], unformattedNameBuffer[13], formattedNameBuffer[12]
  byte volumeLabel[12], directoryEntryCache[32], dataBlock[512], CIDRegisterCopy[16]

  
PUB readData(addressToPut, count) | stride '' 32 Stack Longs

'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'' // Reads data from the file that is currently open and advances the file position by that amount of data.
'' //
'' // Returns the amount of data read from the disk. Reads nothing when at the end of a file.
'' //
'' // This method will do nothing if a file is not currently open for reading or writing.
'' //
'' // If an error occurs this method will abort and return a pointer to a string describing that error.
'' //
'' // AddressToPut - A pointer to the start of a data buffer to fill from disk.
'' // Count - The amount of data to read from disk. The data buffer must be at least this large.
'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  result := addressToPut
  if(lockFileSystem("R") and fileOpenCloseFlag)
    count := ((count <# (currentSize - currentPosition)) #> 0)
    repeat while(count)

      if(((currentPosition >> 9) > currentSector) and fileBlockDirtyFlag)
        fileBlockDirtyFlag := false
        readWriteCurrentSector("W")

      currentByte := currentPosition
      ifnot(readWriteCurrentCluster("R"))
        quit

      stride := (count <# (512 - currentByteInSector))
      bytemove(addressToPut, addressDIREntry, stride)
      currentPosition += stride
      addressToPut += stride
      count -= stride

  unlockFileSystem
  return (addressToPut - result)

PUB fileSize '' 3 Stack Longs

'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'' // Returns the file size.
'' //
'' // This method will do nothing if a file is not currently open for reading or writing.
'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  if(fileOpenCloseFlag)
    return currentSize

PUB fileTell '' 3 Stack Longs

'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'' // Returns the file position.
'' //
'' // This method will do nothing if a file is not currently open for reading or writing.
'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  if(fileOpenCloseFlag)
    return currentPosition

PUB fileSeek(position) '' 25 Stack Longs

'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'' // Changes old the file position. Returns the new file position.
'' //
'' // This method will do nothing if a file is not currently open for reading or writing.
'' //
'' // If an error occurs this method will abort and return a pointer to a string describing that error.
'' //
'' // Position - A byte position in the file. Between 0 and the file size minus 1. Zero if file size is zero.
'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  if(lockFileSystem("R") and fileOpenCloseFlag)
    currentPosition := position := ((position <# (currentSize - 1)) #> 0)
    position >>= 9

    if(position <> currentSector)
      if(fileBlockDirtyFlag~)
        readWriteCurrentSector("W")

      position /= sectorsPerCluster
      currentSector /= sectorsPerCluster
      if(position <> currentSector)
        if(position < currentSector)
          currentCluster := currentFile
          currentSector := 0

        repeat until(position == currentSector++)
          currentCluster := followClusterChain(currentCluster)

      result := true
    elseif((not(currentPosition & $1_FF)) and fileBlockDirtyFlag)
      fileBlockDirtyFlag := false
      readWriteCurrentSector("W")

    currentByte := currentPosition
    if(result)
      readWriteCurrentSector("R")

    result := currentPosition
  unlockFileSystem

PUB closeFile '' 24 Stack Longs

'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'' // Closes the file open for reading, writing, or appending.
'' //
'' // Each included version of this object may work with a different file - Two objects allow for two files, etc.
'' //
'' // Open files are not locked - Two objects can read, write, and append a file at the same time. May cause corruption.
'' //
'' // Open files can also be deleted and moved by other included versions of this object. This will cause corruption.
'' //
'' // All files opened for writing or appending must be closed or they will become corrupted.
'' //
'' // If an error occurs this method will abort and return a pointer to a string describing that error.
'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  if(lockFileSystem("M") and fileOpenCloseFlag~)
    'fileFlush

  unlockFileSystem

PUB openFile(filePathName, mode) | readWriteAppend '' 40 Stack Longs

'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'' // Searches the file system for the specified file in the path name and opens it for reading, writing, or appending.
'' //
'' // Returns the file's name.
'' //
'' // Each included version of this object may work with a different file - Two objects allow for two files, etc.
'' //
'' // Open files are not locked - Two objects can read, write, and append a file at the same time. May cause corruption.
'' //
'' // Open files can also be deleted and moved by other included versions of this object. This will cause corruption.
'' //
'' // All files opened for writing or appending must be closed or they will become corrupted.
'' //
'' // If an error occurs this method will abort and return a pointer to a string describing that error.
'' //
'' // If a file is open when this method is called that file will be closed.
'' //
'' // FilePathName - A file system path string specifying the path of the file to search for.
'' // Mode - A character specifying the mode to use. R-Read, W-Write, A-Append. Default read.
'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  closeFile

  readWriteAppend := ("R" + (constant("W" - "R") & (findNumber(mode, "W", "w") or findNumber(mode, "A", "a"))))
  if(lockFileSystem(readWriteAppend))

    result := evaluateName(evaluatePath(filePathName, readWriteAppend))
    if(isDIRDirectory)
      abortError(Not_A_File)

    currentFile := readDIRCluster
    ifnot(currentFile)
      if(readWriteAppend == "R")
        unlockFileSystem
        return result
     {
      currentFile := createClusterChain(0)
      readWriteCurrentSector("R")
      writeDIRCluster(currentFile)
      readWriteCurrentSector("W")  }

    currentPosition := 0
    currentSize := readDIRSize
    fileDIRByte := currentByte~
    fileDIRSector := currentSector~
    fileDIRCluster := currentCluster
    currentCluster := currentFile
    fileOpenCloseFlag := true
    fileReadWriteFlag := (readWriteAppend == "W")

    if(findNumber(mode, "A", "a") and currentSize)
      mode := currentCluster

      repeat
        currentCluster := mode
        mode := followClusterChain(mode)
      until(isClusterEndOfClusterChain(mode))

      currentPosition := currentSize
      currentByte := (currentPosition - 1)
    readWriteCurrentSector("R")
  unlockFileSystem

{PUB changeDirectory(directoryPathName) '' 38 Stack Longs

'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'' // Searches the file system for the specified directory and changes the current directory to be the specified directory.
'' //
'' // Returns the directory's name.
'' //
'' // If an error occurs this method will abort and return a pointer to a string describing that error.
'' //
'' // If a file is open when this method is called that file will be closed.
'' //
'' // DirectoryPathName - A file system path string specifying the path of the directory to search for.
'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  closeFile

  if(lockFileSystem("R"))
    if(rootWithSpace(directoryPathName))
      result := string("/")
      currentWorkingDirectory := 0

    else
      result := evaluateName(evaluatePath(directoryPathName, "R"))
      ifnot(isDIRDirectory)
        abortError(Not_A_Directory)

      currentWorkingDirectory := readDIRCluster
  unlockFileSystem
}
PUB partitionError '' 3 Stack Longs

'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'' // Returns true if the file system errored and false if not.
'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  if(cardLockID)
    repeat while(lockset(cardLockID - 1))
  
    result := errorNumberFlag~
    lockclr(cardLockID - 1)

PUB bootPartition(filePathName) | bootSectors[64] '' 108 Stack Longs

'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'' // Loads the propeller chip's RAM from the specified file. (Stop any other cogs from accessing the driver before calling).
'' //
'' // If an error occurs this method will abort and return a pointer to a string describing that error.
'' //
'' // If a file is open when this method is called that file will be closed.
'' //
'' // The file to be loaded and run must have a valid program checksum - if not the propeller chip will shutdown.
'' //
'' // The file to be loaded and run must have a valid program base - if not the propeller chip will shutdown.
'' //
'' // FilePathName - A file system path string specifying the path of the file to search for.
'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  openFile(filePathName, "R")
  if(lockFileSystem("R"))
    storeSectorChain(currentFile, @bootSectors, 64)
    unlockFileSystem

    unmountPartition
    lockFileSystem("R")
    readWriteBlock(@bootSectors, "B")
  unlockFileSystem


PUB mountPartition(partition) | cardType '' 37 Stack Longs

'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'' // Mounts the specified partition.
'' //
'' // Returns true if the partition was improperly unmounted the last time it was mounted and false if not.
'' //
'' // If an error occurs this method will abort and return a pointer to a string describing that error.
'' //
'' // If the file system is FAT16 then it can be up to ~4GB.
'' // If the file system is FAT32 then it can be up to ~1TB.
'' //
'' // File sizes up to ~2GB are supported.
'' // Directory sizes up to ~64K entries are supported.
'' //
'' // Partition - Partition number to mount (between 0 and 3). Default 0.
'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  if(cardCogID) 

    unmountPartition
    lockFileSystem("R")
  
    readWriteBlock(@cardType, "M")
    bytemove(@CIDRegisterCopy, @CIDRegister, 16)
    readWriteBlock(0, "R")

    if(((blockToLong(54) & $FF_FF_FF) <> $54_41_46) and ((blockToLong(82) & $FF_FF_FF) <> $54_41_46))
      if(blockToWord(510) <> $AA_55)
        abortError(File_System_Corrupted)

      partition := ((partition & $3) << 4)
      case blockToByte(450 + partition)
        $4, $6, $B .. $C, $E, $14, $16, $1B .. $1C, $1E:
        other: abortError(File_System_Unsupported)

      diskSignature := blockToLong(440)
      hiddenSectors := blockToLong(454 + partition)
      readWriteBlock(0, "R")

    bytemove(@OEMName, addressOfBlock(3), 8)
 
    if(blockToWord(510) <> $AA_55)
      abortError(File_System_Corrupted)

    if(blockToWord(11) <> 512)
      abortError(File_System_Unsupported)

    sectorsPerCluster := blockToByte(13)
    reservedSectorCount := blockToWord(14)
    numberOfFATs := blockToByte(16)
    mediaType := blockToByte(21)

    totalSectors := blockToWord(19)
    ifnot(totalSectors)
      totalSectors := blockToLong(32)

    FATSectorSize := blockToWord(22)
    ifnot(FATSectorSize)
      FATSectorSize := blockToLong(36)

    rootDirectorySectors := ((blockToWord(17) + 15) / 16)
    rootDirectorySectorNumber := (reservedSectorCount + (numberOfFATs * FATSectorSize))
    firstDataSector := (rootDirectorySectorNumber + rootDirectorySectors)
    countOfClusters := ((totalSectors - firstDataSector) / sectorsPerCluster)
    dataSectors := (countOfClusters * sectorsPerCluster)
    fileSystemType := (65_525 =< countOfClusters)

    if(countOfClusters < 4_085)
      abortError(File_System_Unsupported)

    partition := (28 & fileSystemType)
    'ifnot(cardWriteProtectedFlag)
      'byte[addressofBlock(37 + partition)] |= $3
      'readWriteBlock(0, "W")

    result := blockToByte(38 + partition)
    if((result == $28) or (result == $29))
      volumeIdentification := blockToLong(39 + partition)

    if(result == $29)
      bytemove(@volumeLabel, addressOfBlock(43 + partition), 11)
      bytemove(@fileSystemTypeString, addressOfBlock(54 + partition), 8)

    freeClusterCount := -1
    nextFreeCluster := 2

    if(fileSystemType)
      if(blockToWord(40) & $80)
        numberOfFATs := 1
        activeFAT := (blockToWord(40) & $F)

      if(blockToWord(42))
        abortError(File_System_Unsupported)

      rootCluster := blockToLong(44)
      fileSystemInfo := blockToWord(48)
      backupBootSector := blockToWord(50)
      readWriteBlock(fileSystemInfo, "R")

      if((blockToLong(0) == $41_61_52_52) and (blockToLong(484) == $61_41_72_72) and (blockToLong(508) == $AA_55_00_00))
        freeClusterCount := blockToLong(488)
        nextFreeCluster := blockToLong(492)
        ifnot(!nextFreeCluster)
          nextFreeCluster := 2

    readWriteFATBlock(0, "R")
    result := ((readFATEntry(1) >> (14 + (12 & fileSystemType))) <> $3)
    'ifnot(cardWriteProtectedFlag)
      'writeFATEntry(1, clusterMark($3F_FF))
      'readWriteFATBlock(0, "W")

    if(listDirectory("V"))
      readDIRName(@volumeLabel)

    mountedUnmountedFlag := true
    unlockFileSystem

PUB unmountPartition '' 27 Stack Longs

'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'' // Unmounts the mounted partition.
'' //
'' // If an error occurs this method will abort and return a pointer to a string describing that error.
'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  closeFile
  if(lockFileSystem("M"))

    readWriteBlock(0, "R")
    byte[addressofBlock(37 + (28 & fileSystemType))] &= $FC
    readWriteBlock(0, "W")

    if(fileSystemType)
      readWriteBlock(fileSystemInfo, "R")
      longToBlock(488, freeClusterCount)
      longToBlock(492, nextFreeCluster)
      readWriteBlock(fileSystemInfo, "W")

    readWriteFATBlock(0, "R")
    writeFATEntry(1, -1)
    readWriteFATBlock(0, "W")

    readWriteFATBlock(0, "O")

  longfill(@dataStructureAddress, 0, 182)
  unlockFileSystem

PUB FATEngineStart(DOPin, CLKPin, DIPin, CSPin, WPPin, CDPin, RTCReserved1, RTCReserved2, RTCReserved3) '' 15 Stack Longs

'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'' // Starts up the SDC driver running on a cog and checks out a lock for the driver.
'' //
'' // This method should only be called once for any number of included versions of this object.
'' //
'' // This method causes all included versions of this object to need re-mounting when called.
'' //
'' // Returns true on success or false.
'' //
'' // DOPin - The SPI data out pin from the SD card. Between 0 and 31.
'' // CLKPin - The SPI clock pin from the SD card. Between 0 and 31.
'' // DIPin - The SPI data in pin from the SD card. Between 0 and 31.
'' // CSPin - The SPI chip select pin from the SD card. Between 0 and 31.
'' // WPPin - The SPI write protect pin from the SD card holder. Between 0 and 31. -1 if not installed.
'' // CDPin - The SPI write protect pin from the SD card holder. Between 0 and 31. -1 if not installed.
'' // RTCReserved1 - Reserved parameter 1 for RTC compatible driver versions. Pass -1.
'' // RTCReserved2 - Reserved parameter 2 for RTC compatible driver versions. Pass -1. 
'' // RTCReserved3 - Reserved parameter 3 for RTC compatible driver versions. Pass -1. 
'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  FATEngineStop

  readTimeout := (clkfreq / 10)
  writeTimeout := (clkfreq / 2)
  clockCounterSetup := (constant(%00100 << 26) + (CLKPin & $1F))
  dataInCounterSetup := (constant(%00100 << 26) + (DIPin & $1F))

  dataOutPin := (|<DOPin)
  clockPin := (|<CLKPin)
  dataInPin := (|<DIPin)
  chipSelectPin := (|<CSPin)
  writeProtectPin := ((|<WPPin) & (WPPin <> -1))
  cardDetectPin := ((|<CDPin) & (CDPin <> -1))

  blockPntrAddress := @cardBlockAddress
  sectorPntrAddress := @cardSectorAddress
  WPFlagAddress := @cardWriteProtectedFlag
  CDFlagAddress := @cardNotDetectedFlag
  commandFlagAddress := @cardCommandFlag
  errorFlagAddress := @cardErrorFlag
  CSDRegisterAddress := @CSDRegister
  CIDRegisterAddress := @CIDRegister

  cardLockID := locknew
  cardCogID := cognew(@initialization, @CIDPointer)
  if (++cardLockID) and (++cardCogID)
    return true

  FATEngineStop

PUB FATEngineStop '' 3 Stack Longs

'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'' // Shuts down the SDC driver running on a cog and returns the lock used by the driver.
'' //
'' // This method should only be called once for any number of included versions of this object.
'' //
'' // This method causes all included versions of this object to need re-mounting when called.
'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  if(cardCogID)
    cogstop(-1 + cardCogID~)

  if(cardLockID)
    lockret(-1 + cardLockID~)

  bytefill(@CSDRegister, 0, 16)
  bytefill(@CIDRegister, 0, 16)

{PRI rootWithSpace(stringPointer) ' 14 Stack Longs

  stringPointer := skipPastSpace(stringPointer)
  if(findSlash(stringPointer))
    return (not(byte[skipPastSpace(++stringPointer)]))
 }
PRI skipPastSpace(stringPointer) ' 4 Stack Longs

  result := stringPointer
  repeat while(byte[result] == " ")
    result += 1

PRI findByte(stringPointer, thisByte, thatByte) ' 12 Stack Longs

  repeat strsize(stringPointer)
    if(findNumber(byte[stringPointer++], thisByte, thatByte))
      return true

PRI findBreak(stringPointer) ' 14 Stack Longs

  return (findSlash(stringPointer) or (not(byte[stringPointer])))

PRI findSlash(stringPointer) ' 10 Stack Longs

  return findNumber(byte[stringPointer], "/", "\")

PRI findNumber(thisNumber, thatNumber, otherNumber) ' 6 Stack Longs

  return ((thisNumber == thatNumber) or (thisNumber == otherNumber))

PRI evaluatePath(pathName, mode) | entryName[3] ' 34 Stack Longs
    
  currentCluster := currentDirectory := currentWorkingDirectory
  if(findSlash(pathName))
    pathName += 1
    currentCluster := currentDirectory := 0
  
  repeat

    if(findBreak(pathName))
      abortError(Expected_An_Entry)

    pathName := skipPastSpace(pathName)
    formattedNameBuffer[11] := result := 0
    bytefill(@formattedNameBuffer, " ", 11)

    if(byte[pathName] == ".")
      formattedNameBuffer := "."
      if(byte[pathName][1] == ".")
        formattedNameBuffer[1] := "."

    else
      repeat strsize(pathName--)
        if(findSlash(++pathName))
          quit

        if(byte[pathName] == ".")
          result := 0

          pathName := skipPastSpace(pathName + 1)
          repeat strsize(pathName--)
            if(findSlash(++pathName))
              quit

            if(result < 3)
              formattedNameBuffer[8 + result++] := byte[pathName]

          quit

        if(result < 8)
          formattedNameBuffer[result++] := byte[pathName]

      repeat result from 0 to 10
        case formattedNameBuffer[result]
          "a" .. "z": formattedNameBuffer[result] -= 32
          $1 .. $1F, $22, "*" .. ",", "." .. "/", ":" .. "?", "[" .. "]", "|", $7F: formattedNameBuffer[result] := "_"

      if(formattedNameBuffer == " ")
        formattedNameBuffer := "_"

      if(formattedNameBuffer == $E5)
        formattedNameBuffer := $5

    repeat until(findBreak(pathName))
      pathName += 1
     
    currentByte := -32
    currentSector := 0
    repeat
      nextDIREntry

      bytefill(@entryName, 0, 12)
      repeat while(readWriteCurrentCluster("R") and isDIRNotEnd)
        if(isDIRFree or isDIRLongName)
          nextDIREntry

        else
          bytemove(@entryName, addressDIREntry, 11)
          quit

      ifnot(entryName)
        ifnot(byte[pathName] or (mode <> "M"))
          return @formattedNameBuffer

        abortError(Entry_Not_Found)
    until(strcomp(@entryName, @formattedNameBuffer))

    ifnot(byte[pathName] or (mode <> "M"))
      abortError(Entry_Already_Exist)

    if(findSlash(pathName))
      pathName += 1

      ifnot(isDIRDirectory)
        abortError(Expected_A_Directory)

      currentCluster := currentDirectory := readDIRCluster
      next

    quit

  if(isDIRVolumeID)
    abortError(Entry_Not_Accessible)

  if((isDIRReadOnly or isDIRDot) and (mode == "W"))
    abortError(Entry_Not_Modifiable)

  return @formattedNameBuffer

PRI evaluateName(entryName) ' 4 Stack Longs

  if(entryName)
    unformattedNameBuffer[12] := 0

    bytefill(@unformattedNameBuffer, " ", 12)
    bytemove(@unformattedNameBuffer, entryName, 8)

    if(byte[entryName][8] <> " ")
      repeat while(unformattedNameBuffer[7 - result++] ==  " ")
      unformattedNameBuffer[9 - result++] := "."
      bytemove(@unformattedNameBuffer[11 - result], @byte[entryName][8], 3)

    return @unformattedNameBuffer


PRI listDirectory(mode) | sectorBackup, clusterBackup ' 32 Stack Longs

  sectorBackup := currentSector
  clusterBackup := currentCluster
  currentByte := listingByte
  currentSector := listingSector
  currentCluster := listingCluster

  if(currentByteInSector and ((sectorBackup <> currentSector) or (clusterBackup <> currentCluster)))
    readWriteCurrentSector("R")

  repeat while(readWriteCurrentCluster("R") and isDIRNotEnd)
    if(isDIRFree or isDIRLongName or (isDIRVolumeID ^ (mode == "V")))
      nextDIREntry

    else
      readDIRName(@formattedNameBuffer)
      listingByte := (currentByte + 32)
      listingSector := currentSector
      listingCluster := currentCluster
      return @formattedNameBuffer

{PRI listCache ' 14 Stack Longs

  readDIRName(@directoryEntryCache)
  bytemove(@directoryEntryCache[11], (addressDIREntry + 11), 21)
  directoryEntryCache[12] := directoryEntryCache[11]~

PRI listUncache ' 3 Stack Longs

  bytefill(@directoryEntryCache, 0, 32)
  listingSector := listingByte := 0
  listingCluster := currentWorkingDirectory
}
PRI freeDIREntry ' 8 Stack Longs

  byteToBlock(currentByte, $E5)

PRI archiveDIREntry ' 10 Stack Longs

  byte[addressDIREntry + 11] |= $20

PRI nextDIREntry ' 3 Stack Longs

  currentByte += 32

PRI addressDIREntry ' 7 Stack Longs

  return addressOfBlock(currentByte)

PRI isDIRNotEnd ' 7 Stack Longs

  result or= blockToByte(currentByte)

PRI isDIRFree ' 7 Stack Longs

  return (blockToByte(currentByte) == $E5)

PRI isDIRDot ' 7 Stack Longs

  return (blockToByte(currentByte) == ".")
PRI isDIRLongName ' 10 Stack Longs

  return ((readDIRAttributes & $F) == $F)

PRI isDIRDirectory ' 10 Stack Longs

  result or= (readDIRAttributes & $10)

PRI isDIRVolumeID ' 10 Stack Longs

  result or= (readDIRAttributes & $8)

PRI isDIRReadOnly ' 10 Stack Longs

  result or= (readDIRAttributes & $1)

PRI readDIRName(pointer) ' 11 Stack Longs

  bytemove(pointer, addressDIREntry, 11)
  if(byte[pointer] == $5)
    byte[pointer] := $E5

PRI readDIRAttributes ' 7 Stack Longs

  return blockToByte(currentByte + 11)

PRI readDIRCluster ' 10 Stack Longs

  result := ((((blockToWord(currentByte + 20) << 16) & fileSystemType) | blockToWord(currentByte + 26)) & $0F_FF_FF_FF)
  ifnot((not(result)) or isClusterInDataRegion(result))
    abortError(File_System_Corrupted)

PRI readDIRSize ' 7 Stack Longs

  result := blockToLong(currentByte + 28)
  if(result < 0)
    result := posx

PRI readWriteCurrentCluster(readWrite) | nextCluster ' 26 Stack Longs

  ifnot(currentByteInSector)

    if( (fileOpenCloseFlag and (currentByte < 0)) or {
      } (not(fileOpenCloseFlag or (currentByte < constant(65_536 * 32)))) or {
      } (not(currentCluster or fileSystemType or (currentSectorInClusterChain < rootDirectorySectors))) )
      return false

    if( (currentCluster or fileSystemType) and {
      } (not(sectorNumberInCluster)) and {
      } (currentSectorInClusterChain > currentSector) )

      result := currentCluster
      ifnot(result)
        result := rootCluster

      nextCluster := followClusterChain(result)
      if(isClusterEndOfClusterChain(nextCluster))

        if(fileOpenCloseFlag and (currentByte < (currentSize - 1)))
          abortError(File_System_Corrupted)

        if(readWrite == "R")
          return false

        nextCluster := createClusterChain(result)
      currentCluster := nextCluster

    if(fileOpenCloseFlag and fileReadWriteFlag and (currentByte => currentSize))
      currentSector := currentSectorInClusterChain

      zeroBlock
      return true

    readWriteCurrentSector("R")
  return true

PRI readWriteCurrentSector(readWrite) ' 16 Stack Longs

  currentSector := currentSectorInClusterChain

  result := firstSectorOfCluster(currentCluster) + sectorNumberInCluster
  ifnot(currentCluster)

    result := rootDirectorySectorNumber + sectorNumberInRoot
    if(fileSystemType)

      result := firstSectorOfCluster(rootCluster) + sectorNumberInCluster

  readWriteBlock(result, readWrite)

PRI sectorNumberInCluster ' 6 Stack Longs

  return (currentSectorInClusterChain // sectorsPerCluster)

PRI sectorNumberInRoot ' 6 Stack Longs

  return (currentSectorInClusterChain // rootDirectorySectors)

PRI currentByteInSector ' 3 Stack Longs

  return (currentByte & $1_FF)

PRI currentSectorInClusterChain ' 3 Stack Longs

  return (currentByte >> 9)

PRI storeSectorChain(clusterToTrace, storageBufferAddress, storageBufferLength) | storeBuffer, storeCounter ' 29 Stack Longs

  if(isClusterInDataRegion(clusterToTrace) and storageBufferAddress and (storageBufferLength > 0))
    longfill(storageBufferAddress, 0, storageBufferLength)
    result := storageBufferAddress

    repeat until((storageBufferLength =< 0) or isClusterEndOfClusterChain(clusterToTrace))
      storeBuffer := (storageBufferLength <# sectorsPerCluster)

      longfill(storageBufferAddress, (hiddenSectors + firstSectorOfCluster(clusterToTrace)), storeBuffer)
      storageBufferLength -= storeBuffer--
      repeat storeCounter from 0 to storeBuffer
        long[storageBufferAddress] += storeCounter
        storageBufferAddress += 4

      if(storageBufferLength > 0)
        clusterToTrace := followClusterChain(clusterToTrace)

PRI createClusterChain(clusterToLink) ' 21 Stack Longs

  if(FATEntryOffset(nextFreeCluster))
    readWriteFATBlock(nextFreeCluster, "R")

  repeat result from nextFreeCluster to (countOfClusters + 1)

    ifnot(FATEntryOffset(result))
      readWriteFATBlock(result, "R")

    ifnot(readFATEntry(result))
      if(isClusterInDataRegion(clusterToLink))

        if(FATSectorNumber(result) <> FATSectorNumber(clusterToLink))
          readWriteFATBlock(clusterToLink, "R")

        ifnot(isClusterEndOfClusterChain(readFATEntry(clusterToLink)))
          abortError(File_System_Corrupted)

        writeFATEntry(clusterToLink, result)
        if(FATSectorNumber(result) <> FATSectorNumber(clusterToLink))
          readWriteFATBlock(clusterToLink, "W")
          readWriteFATBlock(result, "R")

      writeFATEntry(result, -1)
      readWriteFATBlock(result, "W")

      if(!freeClusterCount)
        freeClusterCount -= 1

      nextFreeCluster := (result + 1)
      if(nextFreeCluster > (countOfClusters + 1))
        nextFreeCluster := 2

      ifnot(fileOpenCloseFlag)
        zeroBlock

        clusterToLink := firstSectorOfCluster(result)
        repeat sectorsPerCluster
          readWriteBlock(clusterToLink++, "W")

      quit

    if(result => (countOfClusters + 1))
      freeClusterCount := -1
      nextFreeCluster := 2
      readWriteCurrentSector("R")
      abortError(Disk_May_Be_Full)

PRI followClusterChain(clusterToFollow) ' 21 Stack Longs

  ifnot(isClusterInDataRegion(clusterToFollow))
    abortError(File_System_Corrupted)

  readWriteFATBlock(clusterToFollow, "R")
  result := readFATEntry(clusterToFollow)

  ifnot(isClusterInDataRegion(result) or isClusterEndOfClusterChain(result))
    abortError(File_System_Corrupted)

PRI isClusterInDataRegion(cluster) ' 4 Stack Longs

  return ((1 < cluster) and (cluster =< (countOfClusters + 1)))

PRI isClusterEndOfClusterChain(cluster) ' 8 Stack Longs

  return ((clusterMark($FF_F8) =< cluster) and (cluster =< clusterMark($FF_FF)))

PRI clusterMark(cluster) ' 4 Stack Longs

  return (cluster | (fileSystemType & ($FF_FF_00 | (cluster << 12))))

PRI firstSectorOfCluster(cluster) ' 4 Stack Longs

  return (((cluster - 2) * sectorsPerCluster) + firstDataSector)

PRI FATSectorNumber(cluster) ' 4 Stack Longs

  return (cluster >> (8 + fileSystemType))

PRI FATEntryOffset(cluster) ' 4 Stack Longs

  return ((cluster & ($FF >> (-fileSystemType))) << (1 - fileSystemType))

PRI readFATEntry(cluster) ' 8 Stack Longs

  cluster := FATEntryOffset(cluster)

  ifnot(fileSystemType)
    return blockToWord(cluster)

  return (blockToLong(cluster) & $F_FF_FF_FF)

PRI writeFATEntry(cluster, value) ' 10 Stack Longs

  cluster := FATEntryOffset(cluster)

  ifnot(fileSystemType)
    wordToBlock(cluster, value)
  else
    longToBlock(cluster, ((value & $F_FF_FF_FF) | (blockToLong(cluster) & $F0_00_00_00)))

PRI readWriteFATBlock(cluster, readWrite) ' 17 Stack Longs

  cluster := (reservedSectorCount + FATSectorNumber(cluster) + (FATSectorSize * activeFAT))

  repeat (((readWrite == "W") & (numberOfFATs - 1)) + 1)
    readWriteBlock(cluster, readWrite)
    cluster += FATSectorSize

PRI readWriteBlock(address, command) ' 12 Stack Longs

  CIDPointer := @CIDRegisterCopy
  cardSectorAddress := (address + hiddenSectors)
  cardBlockAddress := @dataBlock
  cardCommandFlag := command

  repeat while(cardCommandFlag)

  if(cardErrorFlag~)
    abortError(Disk_IO_Error)

PRI lockFileSystem(mode) ' 11 Stack Longs

  if(cardLockID) 
    repeat while(lockset(cardLockID - 1))

  if(cardNotDetectedFlag)
    abortError(Card_Not_Detected)

  if( true{cardWriteProtectedFlag})

    if(mode == "W")
      abortError(Card_Write_Protected)

    if(mode == "M")
      return false

  return mountedUnmountedFlag

PRI abortError(errorNumber) ' 7 Stack Longs

  if((1 =< errorNumber) and (errorNumber =< 5))
    longfill(@dataStructureAddress, 0, 182)

  errorNumberFlag := errorNumber
  unlockFileSystem

  abort @@errorStringAddresses[--errorNumber]

PRI unlockFileSystem ' 3 Stack Longs

  if(cardLockID) 
    lockclr(cardLockID - 1)

PRI blockToLong(index) ' 4 Stack Longs

  bytemove(@result, @dataBlock[(index & $1_FF)], 4)

PRI blockToWord(index) ' 4 Stack Longs

  bytemove(@result, @dataBlock[(index & $1_FF)], 2)

PRI blockToByte(index) ' 4 Stack Longs

  return dataBlock[(index & $1_FF)]

PRI longToBlock(index, value) ' 5 Stack Longs

  bytemove(@dataBlock[(index & $1_FF)], @value, 4)

PRI wordToBlock(index, value) ' 5 Stack Longs

  bytemove(@dataBlock[(index & $1_FF)], @value, 2)

PRI byteToBlock(index, value) ' 5 Stack Longs

  dataBlock[(index & $1_FF)] := value

PRI zeroBlock ' 3 Stack Longs

  bytefill(@dataBlock, 0, 512)

PRI addressOfBlock(index) ' 4 Stack Longs

  return @dataBlock[(index & $1_FF)]

PUB Return_Address ''used to get address where assembly code is so we can re-purpose space
    return(@initialization)

DAT

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       SDC Driver
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

                        org     0

' //////////////////////Initialization/////////////////////////////////////////////////////////////////////////////////////////

initialization          mov     ctra,                  clockCounterSetup            ' Setup counter modules.
                        mov     ctrb,                  dataInCounterSetup           '

                        mov     cardMounted,           #0                           ' Skip to instruction handle.
                        jmp     #instructionWait                                    '

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Command Center
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

instructionFlush        call    #flushSPI                                           ' Clean up the SPI bus.
                        call    #shutdownSPI                                        '

instructionHalt         cmp     cardCommand,           #"B" wz                      ' Halt the chip if booting failure.
if_z                    mov     buffer,                #$02                         '
if_z                    clkset  buffer                                              '

instructionError        neg     buffer,                #1                           ' Assert error flag and unmount card.
                        wrbyte  buffer,                errorFlagAddress             '
                        mov     cardMounted,           #0                           '

                        mov     counter,               #16                          ' Setup to clear registers.
                        mov     SPIExtraBuffer,        CIDRegisterAddress           '
                        mov     SPIExtraCounter,       CSDRegisterAddress           '

instructionClearLoop    wrbyte  fiveHundredAndTwelve,  SPIExtraBuffer               ' Clear registers.
                        add     SPIExtraBuffer,        #1                           '
                        wrbyte  fiveHundredAndTwelve,  SPIExtraCounter              '
                        add     SPIExtraCounter,       #1                           '
                        djnz    counter,               #instructionClearLoop        '

' //////////////////////Instruction Handle/////////////////////////////////////////////////////////////////////////////////////

instructionLoop         wrbyte  fiveHundredAndTwelve,  commandFlagAddress           ' Clear instruction.

instructionWait         test    cardDetectPin,         ina wz                       ' Update the CD pin state.
                        muxnz   buffer,                #$FF                         '
                        wrbyte  buffer,                CDFlagAddress                '

                        test    writeProtectPin,       ina wc                       ' Update the WP pin state
                        muxc    buffer,                #$FF                         '
                        wrbyte  buffer,                WPFlagAddress                '

if_nz                   mov     cardMounted,           #0                           ' Check the command.
                        rdbyte  cardCommand,           commandFlagAddress           '
                        tjz     cardCommand,           #instructionWait             '

if_z                    cmp     cardCommand,           #"M" wz                      ' If mounting was requested do it.
if_z                    jmp     #mountCard                                          '

                        cmp     cardCommand,           #"O" wz                      ' If operation was requested do it.
if_z                    jmp     #instructionLoop                                    '

                        cmp     cardMounted,           #0 wz                        ' Check if the card is mounted.
if_z                    jmp     #instructionError                                   '

                        mov     counter,               #16                          ' Setup to compare CIDs.
                        mov     SPIBuffer,             CIDRegisterAddress           '
                        rdlong  SPICounter,            par                          '

CIDCompareLoop          rdbyte  SPIExtraBuffer,        SPIBuffer                    ' Compare CIDs.
                        add     SPIBuffer,             #1                           '
                        rdbyte  SPIExtraCounter,       SPICounter                   '
                        add     SPICounter,            #1                           '
                        cmp     SPIExtraBuffer,        SPIExtraCounter wz           '
if_nz                   jmp     #instructionError                                   '
                        djnz    counter,               #CIDCompareLoop              '

                        cmp     cardCommand,           #"B" wz                      ' If rebooting was requested do it.
if_z                    jmp     #rebootChip                                         '

                        cmp     cardCommand,           #"R" wz                      ' If reading was requested do it.
if_z                    jmp     #readBlock                                          '

                        cmp     cardCommand,           #"W" wz                      ' If writing was requested do it. (fall in)
if_nz_or_c              jmp     #instructionError                                   '

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Write Block
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

writeBlock              rdlong  SPIextraBuffer,        sectorPntrAddress            ' Write a block.
                        shl     SPIextraBuffer,        SPIShift                     '
                        movs    commandSPIIndex,       #($40 | 24)                  '
                        call    #commandSPI                                         '

                        tjnz    SPIextraBuffer,        #instructionFlush            ' If failure abort.

                        call    #readSPI                                            ' Send dummy byte.

                        mov     phsb,                  #$FE                         ' Send start of data token.
                        call    #writeSPI                                           '

                        mov     counter,               fiveHundredAndTwelve         ' Setup loop.
                        rdlong  buffer,                blockPntrAddress             '

writeBlockLoop          rdbyte  phsb,                  buffer                       ' Write data out from memory.
                        add     buffer,                #1                           '
                        call    #writeSPI                                           '
                        djnz    counter,               #writeBlockLoop              '

                        call    #wordSPI                                            ' Write out the bogus 16 bit CRC.

                        call    #repsonceSPI                                        ' If failure abort.
                        and     SPIextraBuffer,        #$1F                         '
                        cmp     SPIextraBuffer,        #$5 wz                       '
if_nz                   jmp     #instructionFlush                                   '

                        wrbyte  fiveHundredAndTwelve,  commandFlagAddress           ' Clear instruction.

                        mov     counter,               cnt                          ' Setup loop.

writeBlockBusyLoop      call    #readSPI                                            ' Wait until the card is not busy.
                        cmp     SPIBuffer,             #0 wz                        '
if_z                    mov     SPICounter,            cnt                          '
if_z                    sub     SPICounter,            counter                      '
if_z                    cmpsub  writeTimeout,          SPICounter wc, nr            '
if_z_and_c              jmp     #writeBlockBusyLoop                                 '

if_z                    mov     cardMounted,           #0                           ' Unmount card on failure.

                        call    #shutdownSPI                                        ' Shutdown SPI clock.

                        jmp     #instructionWait                                    ' Return. (instruction already cleared)

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Read Block
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

readBlock               rdlong  SPIextraBuffer,        sectorPntrAddress            ' Read a block.
                        shl     SPIextraBuffer,        SPIShift                     '
                        movs    commandSPIIndex,       #($40 | 17)                  '
                        call    #commandSPI                                         '

                        tjnz    SPIextraBuffer,        #instructionFlush            ' If failure abort.

                        mov     counter,               cnt                          ' Setup loop.

readBlockWaitLoop       call    #readSPI                                            ' Wait until the card sends the data.
                        cmp     SPIBuffer,             #$FF wz                      '
if_z                    mov     SPICounter,            cnt                          '
if_z                    sub     SPICounter,            counter                      '
if_z                    cmpsub  readTimeout,           SPICounter wc, nr            '
if_z_and_c              jmp     #readBlockWaitLoop                                  '

                        cmp     SPIBuffer,             #$FE wz                      ' If failure abort.
if_nz                   jmp     #instructionFlush                                   '

                        mov     counter,               fiveHundredAndTwelve         ' Setup loop.
readBlockModify         rdlong  buffer,                blockPntrAddress             '

readBlockLoop           call    #readSPI                                            ' Read data into memory.
                        wrbyte  SPIBuffer,             buffer                       '
                        add     buffer,                #1                           '
                        djnz    counter,               #readBlockLoop               '

                        call    #wordSPI                                            ' Shutdown SPI clock.
                        call    #shutdownSPI                                        '

readBlock_ret           jmp     #instructionLoop                                    ' Return. Becomes RET when rebooting.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Reboot Chip
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

rebootChip              mov     counter,               #8                           ' Setup cog stop loop.
                        cogid   buffer                                              '

rebootCogLoop           sub     counter,               #1                           ' Stop all cogs but this one.
                        cmp     counter,               buffer wz                    '
if_nz                   cogstop counter                                             '
                        tjnz    counter,               #rebootCogLoop               '

                        mov     counter,               #8                           ' Free all locks. (07654321)
rebootLockLoop          lockclr counter                                             '
                        lockret counter                                             '
                        djnz    counter,               #rebootLockLoop              '

' //////////////////////Setup Memory///////////////////////////////////////////////////////////////////////////////////////////

                        mov     counter,               #64                          ' Setup to grab all sector addresses.
                        rdlong  buffer,                sectorPntrAddress            '

rebootSectorLoadLoop    rdlong  cardRebootSectors,     buffer                       ' Get all addresses of the 64 sectors.
                        add     buffer,                #4                           '
                        add     rebootSectorLoadLoop,  fiveHundredAndTwelve         '
                        djnz    counter,               #rebootSectorLoadLoop        '

' //////////////////////Fill Memory////////////////////////////////////////////////////////////////////////////////////////////

                        mov     readBlock,             #0                           ' Fill these two commands with NOPs.
                        mov     readBlockModify,       #0                           '

                        mov     SPIExtraCounter,       #64                          ' Ready to fill all memory. Pointer at 0.
                        mov     buffer,                #0                           '

rebootCodeFillLoop      mov     SPIextraBuffer,        cardRebootSectors            ' Reuse read block code. Finish if 0 seen.
                        tjz     SPIextraBuffer,        #rebootCodeClear             '
                        add     rebootCodeFillLoop,    #1                           '
                        call    #readBlock                                          '
                        djnz    SPIExtraCounter,       #rebootCodeFillLoop          '

' //////////////////////Clear Memory///////////////////////////////////////////////////////////////////////////////////////////

rebootCodeClear         rdword  counter,               #$8                          ' Setup to clear the rest.
                        mov     SPIExtraCounter,       fiveHundredAndTwelve         '
                        shl     SPIExtraCounter,       #6                           '

rebootCodeClearLoop     wrbyte  fiveHundredAndTwelve,  counter                      ' Clear the remaining memory.
                        add     counter,               #1                           '
                        cmp     counter,               SPIExtraCounter wz           '
if_nz                   jmp     #rebootCodeClearLoop                                '

                        rdword  buffer,                #$A                          ' Setup the stack markers.
                        sub     buffer,                #4                           '
                        wrlong  rebootStackMarker,     buffer                       '
                        sub     buffer,                #4                           '
                        wrlong  rebootStackMarker,     buffer                       '

' //////////////////////Verify Memory//////////////////////////////////////////////////////////////////////////////////////////

                        mov     counter,               #0                           ' Setup to compute the checksum.

rebootCheckSumLoop      sub     SPIExtraCounter,       #1                           ' Compute the RAM checksum.
                        rdbyte  buffer,                SPIExtraCounter              '
                        add     counter,               buffer                       '
                        tjnz    SPIExtraCounter,       #rebootCheckSumLoop          '

                        and     counter,               #$FF                         ' Crash if checksum not 0.
                        tjnz    counter,               #instructionHalt             '

                        rdword  buffer,                #$6                          ' Crash if program base invalid.
                        cmp     buffer,                #$10 wz                      '
if_nz                   jmp     #instructionHalt                                    '

' //////////////////////Boot Interpreter///////////////////////////////////////////////////////////////////////////////////////

                        rdbyte  buffer,                #$4                          ' Switch clock mode for PLL stabilization.
                        and     buffer,                #$F8                         '
                        clkset  buffer                                              '

rebootDelayLoop         djnz    twentyMilliseconds,    #rebootDelayLoop             ' Allow PLL to stabilize.

                        rdbyte  buffer,                #$4                          ' Switch to new clock mode.
                        clkset  buffer                                              '

                        coginit rebootInterpreter                                   ' Restart running new code.

                        cogid   buffer                                              ' Shutdown.
                        cogstop buffer                                              '

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Mount Card
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

mountCard               mov     SPITiming,             #0                           ' Setup SPI parameters.
                        call    #flushSPI                                           '

' //////////////////////Go Idle State//////////////////////////////////////////////////////////////////////////////////////////

                        mov     SPITimeout,            cnt                          ' Setup to try for 1 second.

enterIdleStateLoop      movs    commandSPIIndex,       #($40 | 0)                   ' Send out command 0.
                        mov     SPIextraBuffer,        #0                           '
                        movs    commandSPICRC,         #$95                         '
                        call    #commandSPI                                         '
                        call    #shutdownSPI                                        '

                        cmp     SPIextraBuffer,        #1 wz                        ' Check time.
if_nz                   call    #timeoutSPI                                         '
if_nz                   jmp     #enterIdleStateLoop                                 '

' //////////////////////Send Interface Condition///////////////////////////////////////////////////////////////////////////////

                        movs    commandSPIIndex,       #($40 | 8)                   ' Send out command 8.
                        mov     SPIextraBuffer,        #$1_AA                       '
                        movs    commandSPICRC,         #$87                         '
                        call    #commandSPI                                         '
                        call    #longSPI                                            '
                        call    #shutdownSPI                                        '

                        test    SPIextraBuffer,        #$4 wz                       ' If failure goto SD 1.X initialization.
if_nz                   jmp     #exitIdleState_SD                                   '

                        and     SPIResponce,           #$1_FF                       ' SD 2.0/3.0 initialization.
                        cmp     SPIResponce,           #$1_AA wz                    '
if_nz                   jmp     #instructionError                                   '

' //////////////////////Send Operating Condition///////////////////////////////////////////////////////////////////////////////

exitIdleState_SD        movs    commandSPICRC,         #$FF                         ' Setup to try for 1 second.
                        mov     SPITimeout,            cnt                          '

exitIdleStateLoop_SD    movs    commandSPIIndex,       #($40 | 55)                  ' Send out command 55.
                        mov     SPIextraBuffer,        #0                           '
                        call    #commandSPI                                         '
                        call    #shutdownSPI                                        '

                        test    SPIextraBuffer,        #$4 wz                       ' If failure goto MMC initialization.                                 '
if_nz                   jmp     #exitIdleState_MMC                                  '

                        movs    commandSPIIndex,       #($40 | 41)                  ' Send out command 41 with HCS bit set.
                        mov     SPIextraBuffer,        HCSBitMask                   '
                        call    #commandSPI                                         '
                        call    #shutdownSPI                                        '

                        cmp     SPIextraBuffer,        #0 wz                        ' Check time.
if_nz                   call    #timeoutSPI                                         '
if_nz                   jmp     #exitIdleStateLoop_SD                               '

                        rdlong  buffer,                sectorPntrAddress            ' It's an SDC card.
                        wrlong  itsAnSDCard,           buffer                       '
                        jmp     #readOCR                                            '

' //////////////////////Send Operating Condition///////////////////////////////////////////////////////////////////////////////

exitIdleState_MMC       mov     SPITimeout,            cnt                          ' Setup to try for 1 second.

exitIdleStateLoop_MMC   movs    commandSPIIndex,       #($40 | 1)                   ' Send out command 1.
                        mov     SPIextraBuffer,        HCSBitMask                   '
                        call    #commandSPI                                         '
                        call    #shutdownSPI                                        '

                        cmp     SPIextraBuffer,        #0 wz                        ' Check time.
if_nz                   call    #timeoutSPI                                         '
if_nz                   jmp     #exitIdleStateLoop_MMC                              '

                        rdlong  buffer,                sectorPntrAddress            ' It's an MMC card.
                        wrlong  itsAnMMCard,           buffer                       '

' //////////////////////Read OCR Register//////////////////////////////////////////////////////////////////////////////////////

readOCR                 movs    commandSPIIndex,       #($40 | 58)                  ' Ask the card for its OCR register.
                        mov     SPIextraBuffer,        #0                           '
                        call    #commandSPI                                         '
                        call    #longSPI                                            '
                        call    #shutdownSPI                                        '

                        tjnz    SPIextraBuffer,        #instructionError            ' If failure abort.

                        test    SPIResponce,           OCRCheckMask wz              ' If voltage not supported abort.
                        shl     SPIResponce,           #1 wc                        '
if_z_or_nc              jmp     #instructionError                                   '

                        shl     SPIResponce,           #1 wc                        ' SDHC/SDXC supported or not.
if_c                    mov     SPIShift,              #0                           '
if_nc                   mov     SPIShift,              #9                           '

' //////////////////////Read CSD Register//////////////////////////////////////////////////////////////////////////////////////

                        movs    commandSPIIndex,       #($40 | 9)                   ' Ask the card for its CSD register.
                        mov     SPIextraBuffer,        #0                           '
                        call    #commandSPI                                         '

                        tjnz    SPIextraBuffer,        #instructionFlush            ' If failure abort.
                        call    #repsonceSPI                                        '
                        cmp     SPIextraBuffer,        #$FE wz                      '
if_nz                   jmp     #instructionFlush                                   '

                        mov     counter,               #16                          ' Setup to read the CSD register.
                        mov     buffer,                CSDRegisterAddress           '

readCSDLoop             call    #readSPI                                            ' Read the CSD register in.
                        wrbyte  SPIBuffer,             buffer                       '
                        add     buffer,                #1                           '
                        djnz    counter,               #readCSDLoop                 '

                        call    #wordSPI                                            ' Shutdown SPI clock.
                        call    #shutdownSPI                                        '

' //////////////////////Read CID Register//////////////////////////////////////////////////////////////////////////////////////

                        movs    commandSPIIndex,       #($40 | 10)                  ' Ask the card for its CID register.
                        mov     SPIextraBuffer,        #0                           '
                        call    #commandSPI                                         '

                        tjnz    SPIextraBuffer,        #instructionFlush            ' If failure abort.
                        call    #repsonceSPI                                        '
                        cmp     SPIextraBuffer,        #$FE wz                      '
if_nz                   jmp     #instructionFlush                                   '

                        mov     counter,               #16                          ' Setup to read the CID register.
                        mov     buffer,                CIDRegisterAddress           '

readCIDLoop             call    #readSPI                                            ' Read the CID register in.
                        wrbyte  SPIBuffer,             buffer                       '
                        add     buffer,                #1                           '
                        djnz    counter,               #readCIDLoop                 '

                        call    #wordSPI                                            ' Shutdown SPI clock.
                        call    #shutdownSPI                                        '

' //////////////////////Set Block Length///////////////////////////////////////////////////////////////////////////////////////

                        movs    commandSPIIndex,       #($40 | 16)                  ' Send out command 16.
                        mov     SPIextraBuffer,        fiveHundredAndTwelve         '
                        call    #commandSPI                                         '
                        call    #shutdownSPI                                        '

                        tjnz    SPIextraBuffer,        #instructionError            ' If failure abort.

                        neg     SPITiming,             #1                           ' Setup SPI parameters.

' //////////////////////Setup Card Variables///////////////////////////////////////////////////////////////////////////////////

                        neg     cardMounted,           #1                           ' Return.
                        jmp     #instructionLoop                                    '

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Flush SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

flushSPI                or      dira,                  dataInPin                    ' Untristate the I/O lines.
                        or      dira,                  clockPin                     '

                        mov     SPIExtraCounter,       #74                          ' Send out more than 74 clocks.
flushSPILoop            call    #readSPI                                            '
                        djnz    SPIExtraCounter,       #flushSPILoop                '

flushSPI_ret            ret                                                         ' Return.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Timeout SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

timeoutSPI              mov     SPICounter,            cnt                          ' Check if a second has passed.
                        sub     SPICounter,            SPITimeout                   '
                        rdlong  SPIBuffer,             #0                           '
                        cmpsub  SPIBuffer,             SPICounter wc, nr            '
if_nc                   jmp     #instructionError                                   '

timeoutSPI_ret          ret                                                         ' Return.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Command SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

commandSPI              or      dira,                  dataInPin                    ' Untristate the I/O lines.
                        or      dira,                  clockPin                     '

                        or      dira,                  chipSelectPin                ' Activate the SPI bus.
                        call    #readSPI                                            '

commandSPIIndex         mov     phsb,                  #$FF                         ' Send out command.
                        call    #writeSPI                                           '

                        movs    writeSPI,              #32                          ' Send out parameter.
                        mov     phsb,                  SPIextraBuffer               '
                        call    #writeSPI                                           '
                        movs    writeSPI,              #8                           '

commandSPICRC           mov     phsb,                  #$FF                         ' Send out CRC token.
                        call    #writeSPI                                           '

                        call    #repsonceSPI                                        ' Read in responce.

commandSPI_ret          ret                                                         ' Return.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Responce SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

repsonceSPI             mov     SPIextraBuffer,         #9                          ' Setup responce poll counter.

repsonceSPILoop         call    #readSPI                                            ' Poll for responce.
                        cmpsub  SPIBuffer,              #$FF wc, nr                 '
if_c                    djnz    SPIextraBuffer,         #repsonceSPILoop            '

                        mov     SPIextraBuffer,         SPIBuffer                   ' Move responce into return value.

repsonceSPI_ret         ret                                                         ' Return.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Result SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

longSPI                 add     readSPI,               #16                          ' Read in 32, 16, or 8 bits.
wordSPI                 add     readSPI,               #8                           '
byteSPI                 call    #readSPI                                            '
                        movs    readSPI,               #8                           '

                        mov     SPIResponce,           SPIBuffer                    ' Move long into return value.

byteSPI_ret                                                                         ' Return.
wordSPI_ret                                                                         '
longSPI_ret             ret                                                         '

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Shutdown SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

shutdownSPI             call    #readSPI                                            ' Shutdown the SPI bus.
                        andn    dira,                  chipSelectPin                '
                        call    #readSPI                                            '

                        andn    dira,                  dataInPin                    ' Tristate the I/O lines.
                        andn    dira,                  clockPin                     '

shutdownSPI_ret         ret                                                         ' Return.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Read SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

readSPI                 mov     SPICounter,            #8                           ' Setup counter to read in 1 - 32 bits.
                        mov     SPIBuffer,             #0 wc                        '

readSPIAgain            mov     phsa,                  #0                           ' Start clock low.
                        tjnz    SPITiming,             #readSPISpeed                '

' //////////////////////Slow Reading///////////////////////////////////////////////////////////////////////////////////////////

                        movi    frqa,                  #%0000_0001_0                ' Start the clock - read 1 .. 32 bits.

readSPILoop             waitpne clockPin,              clockPin                     ' Get bit.
                        rcl     SPIBuffer,             #1                           '
                        waitpeq clockPin,              clockPin                     '
                        test    dataOutPin,            ina wc                       '

                        djnz    SPICounter,            #readSPILoop                 ' Loop until done.
                        jmp     #readSPIFinish                                      '

' //////////////////////Fast Reading///////////////////////////////////////////////////////////////////////////////////////////

readSPISpeed            movi    frqa,                  #%0010_0000_0                ' Start the clock - read 8 bits.

                        test    dataOutPin,            ina wc                       ' Read in data.
                        rcl     SPIBuffer,             #1                           '
                        test    dataOutPin,            ina wc                       '
                        rcl     SPIBuffer,             #1                           '
                        test    dataOutPin,            ina wc                       '
                        rcl     SPIBuffer,             #1                           '
                        test    dataOutPin,            ina wc                       '
                        rcl     SPIBuffer,             #1                           '
                        test    dataOutPin,            ina wc                       '
                        rcl     SPIBuffer,             #1                           '
                        test    dataOutPin,            ina wc                       '
                        rcl     SPIBuffer,             #1                           '
                        test    dataOutPin,            ina wc                       '
                        rcl     SPIBuffer,             #1                           '
                        test    dataOutPin,            ina wc                       '

' //////////////////////Finish Up//////////////////////////////////////////////////////////////////////////////////////////////

readSPIFinish           mov     frqa,                  #0                           ' Stop the clock.
                        rcl     SPIBuffer,             #1                           '

                        cmpsub  SPICounter,            #8                           ' Read in any remaining bits.
                        tjnz    SPICounter,            #readSPIAgain                '

readSPI_ret             ret                                                         ' Return. Leaves the clock high.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Write SPI
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

writeSPI                mov     SPICounter,            #8                           ' Setup counter to write out 1 - 32 bits.
                        ror     phsb,                  SPICounter                   '

writeSPIAgain           mov     phsa,                  #0                           ' Start clock low.
                        tjnz    SPITiming,             #writeSPISpeed               '

' //////////////////////Slow Writing//////////////////////////////////////////////////////////////////////////////////////////

                        movi    frqa,                  #%0000_0001_0                ' Start the clock - write 1 .. 32 bits.

writeSPILoop            waitpeq clockPin,              clockPin                     ' Set bit.
                        waitpne clockPin,              clockPin                     '
                        shl     phsb,                  #1                           '

                        djnz    SPICounter,            #writeSPILoop                ' Loop until done.
                        jmp     #writeSPIFinish                                     '

' //////////////////////Fast Writing//////////////////////////////////////////////////////////////////////////////////////////

writeSPISpeed           movi    frqa,                  #%0100_0000_0                ' Write out data.
                        shl     phsb,                  #1                           '
                        shl     phsb,                  #1                           '
                        shl     phsb,                  #1                           '
                        shl     phsb,                  #1                           '
                        shl     phsb,                  #1                           '
                        shl     phsb,                  #1                           '
                        shl     phsb,                  #1                           '

' //////////////////////Finish Up//////////////////////////////////////////////////////////////////////////////////////////////

writeSPIFinish          mov     frqa,                  #0                           ' Stop the clock.

                        cmpsub  SPICounter,            #8                           ' Write out any remaining bits.
                        shl     phsb,                  #1                           '
                        tjnz    SPICounter,            #writeSPIAgain               '
                        neg     phsb,                  #1                           '

writeSPI_ret            ret                                                         ' Return. Leaves the clock low.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'                       Data
' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 
fiveHundredAndTwelve    long    $2_00                                               ' Constant 512.
twentyMilliseconds      long    (((20 * (20_000_000 / 1_000)) / 4) / 1)             ' Constant 100,000.

itsAnSDCard             long    $00_43_44_53                                        ' Card type SD token.
itsAnMMCard             long    $00_43_4D_4D                                        ' Card type MMC token.

OCRCheckMask            long    %00_000000_11111111_00000000_00000000               ' Parameter check mask for OCR bits.
HCSBitMask              long    %01_000000_00000000_00000000_00000000               ' Parameter bit mask for HCS bit.

rebootInterpreter       long    (($00_01 << 18) | ($3C_01 << 4) | ($00_00 << 0))    ' Spin interpreter text boot information.
rebootStackMarker       long    $FF_F9_FF_FF                                        ' Spin interpreter stack boot information.

' //////////////////////Configuration Settings/////////////////////////////////////////////////////////////////////////////////

readTimeout             long    0                                                   ' 100 millisecond timeout.
writeTimeout            long    0                                                   ' 500 millisecond timeout.
clockCounterSetup       long    0                                                   ' Clock control.
dataInCounterSetup      long    0                                                   ' Data in control.

' //////////////////////Pin Masks//////////////////////////////////////////////////////////////////////////////////////////////

dataOutPin              long    0
clockPin                long    0
dataInPin               long    0
chipSelectPin           long    0
writeProtectPin         long    0
cardDetectPin           long    0

' //////////////////////Addresses//////////////////////////////////////////////////////////////////////////////////////////////

blockPntrAddress        long    0
sectorPntrAddress       long    0
WPFlagAddress           long    0
CDFlagAddress           long    0
commandFlagAddress      long    0
errorFlagAddress        long    0
CSDRegisterAddress      long    0
CIDRegisterAddress      long    0

' //////////////////////Run Time Variables/////////////////////////////////////////////////////////////////////////////////////

buffer                  res     1
counter                 res     1

' //////////////////////Card Variables/////////////////////////////////////////////////////////////////////////////////////////

cardCommand             res     1
cardMounted             res     1

cardRebootSectors       res     64

' //////////////////////SPI Variables//////////////////////////////////////////////////////////////////////////////////////////

SPIShift                res     1
SPITiming               res     1
SPITimeout              res     1
SPIResponce             res     1
SPIBuffer               res     1
SPICounter              res     1
SPIExtraBuffer          res     1
SPIExtraCounter         res     1

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

                        fit     496

DAT

' //////////////////////Driver Variable Array//////////////////////////////////////////////////////////////////////////////////

cardBlockAddress        long 0 ' Address of the data block in memory to read bytes from and write bytes to.
cardSectorAddress       long 0 ' Address of the sector on the memory card to write bytes to and read bytes from.
cardWriteProtectedFlag  byte 0 ' The secure digital card driver write protected flag.
cardNotDetectedFlag     byte 0 ' The secure digital card driver not card detected flag.
cardCommandFlag         byte 0 ' The secure digital card driver method command flag.
cardErrorFlag           byte 0 ' The secure digital card driver method result flag.

CSDRegister             byte 0[16] ' The SD/MMC CSD register.
CIDRegister             byte 0[16] ' The SD/MMC CID register.

CIDPointer              long 0 ' Pointer to the SD/MMC CID register copy to compare.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DAT

' //////////////////////String Address Array///////////////////////////////////////////////////////////////////////////////////

errorStringAddresses    word @errorString1
                        word @errorString2
                        word @errorString3
                        word @errorString4
                        word @errorString5
                        word @errorString6
                        word @errorString7
                        word @errorString8
                        word @errorString9
                        word @errorString10
                        word @errorString11
                        word @errorString12
                        word @errorString13
                        word @errorString14
                        word @errorString15
                        word @errorString16
                        word @errorString17
                        word @errorString18

' //////////////////////String Array///////////////////////////////////////////////////////////////////////////////////////////

errorString1            byte "Disk IO Error" ' , 0
errorString2            byte 0 ' "Clock IO Error", 0
errorString3            byte "File System Corrupted", 0
errorString4            byte "File System Unsupported", 0
errorString5            byte "Card Not Detected", 0
errorString6            byte "Card Write Protected", 0
errorString7            byte "Disk May Be Full", 0
errorString8            byte "Directory Full", 0
errorString9            byte "Expected An Entry", 0
errorString10           byte "Expected A Directory", 0
errorString11           byte "Entry Not Accessible", 0
errorString12           byte "Entry Not Modifiable", 0
errorString13           byte "Entry Not Found", 0
errorString14           byte "Entry Already Exist", 0
errorString15           byte "Directory Link Missing", 0
errorString16           byte "Directory Not Empty", 0
errorString17           byte "Not A Directory", 0
errorString18           byte "Not A File", 0

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DAT

' //////////////////////Global Variable Array//////////////////////////////////////////////////////////////////////////////////
{
cardClockID             byte 0 ' The secure digital card driver real time clock installed flag. }
cardLockID              byte 0 ' The secure digital card driver lock number.
cardCogID               byte 0 ' The secure digital card driver cog number.

' /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

{{

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                  TERMS OF USE: MIT License
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
}}