CON
  _clkmode = xtal1 + pll16x     
  _xinfreq = 5_000_000     

  spiDO     = 21
  spiClk    = 24
  spiDI     = 20
  spiCS     = 25

  audioLeft = 11 
  audioRight= 10
  
  SAMPLE_RATE = 44_100
  
  SECTOR_SAMPLES = 512/4
  
OBJ
fat : "SD-MMC_FATEngine"

VAR

long sector_rq,sector_ack

byte buffer[1024]

PUB main
              
sector_ack := -1
decoderStart(audioLeft,audioRight)
fat.FATEngineStart(spiDO,spiClk,spiDI,spiCS,-1,-1,-1,-1,-1)  
fat.mountPartition(0)
fat.openFile(string("test.raw"),"r")

repeat
  if sector_ack <> sector_rq
    ifnot fat.readData(@buffer+(sector_rq&1)<<9,512)
      '' end of file
      return
    sector_ack := sector_rq

PRI decoderStart(left,right)

sampleCycles := clkfreq/SAMPLE_RATE
sectorRqPtr := @sector_rq    
sectorAckPtr := @sector_ack
musicBufPtr := @buffer

tempValue1       := $18000000 | left
tempValue2       := $18000000 | right
tempValue3       := ((1 << right) | (1 << left)) & !1

cognew(@entry,0)

DAT
              org
entry
              mov frqa,bit31
              mov frqb,bit31     
              mov ctra,tempValue1
              mov ctrb,tempValue2
              mov dira,tempValue3 
              mov cnt,cnt
              add cnt,sampleCycles

              mov sectorLeft,sectorLength 
loop                                     
              cmp sectorLeft,sectorLength wc
        if_b  jmp #:doDecode 
              ' Check for ACK
              rdlong tempValue1,sectorAckPtr
              cmp tempValue1,sectorCurrent wz
        if_nz jmp #:doOutput ' panicc
              ' Init pointers
              mov uDatPtr,musicBufPtr
              test sectorCurrent,#1 wz
        if_nz add uDatPtr,bit9
              add uPatPtr,#8 ' branch info (NYI)
              ' Prepare next
              mov sectorNext,sectorCurrent
              add sectorNext,#1
              wrlong sectorNext,sectorRqPtr

:doDecode
              rdlong musicOutR,uDatPtr
              mov musicOutL,musicOutR
              add uDatPtr,#4
              
              sar musicOutR,#16
              shl musicOutR,#15
              shl musicOutL,#16
              sar musicOutR,#1

              ' advance sectorLeft
              sub sectorLeft,#1 wz
        if_z  mov sectorLeft,sectorLength 
        if_z  mov sectorCurrent,sectorNext 

:doOutput
              ' do output             
              mov tempValue1,musicOutL
              add tempValue1,bit31     
              mov tempValue2,musicOutR   
              add tempValue2,bit31                     

              waitcnt cnt,sampleCycles
              mov frqa,tempValue1
              mov frqb,tempValue2           
              jmp #loop

bit31         long |<31       
bit9          long |<9
sectorLength  long SECTOR_SAMPLES

sectorCurrent long 0
sectorNext    long 0
sampleCycles  long 0
sectorRqPtr   long 0
sectorAckPtr  long 0
musicBufPtr   long 0
tempValue1    long 0
tempValue2    long 0
tempValue3    long 0     
musicOutL     res 1
musicOutR     res 1
uDatPtr       res 1

              fit 496