CON
  _clkmode = xtal1 + pll16x     
  _xinfreq = 5_000_000     

  spiDO     = 21
  spiClk    = 24
  spiDI     = 20
  spiCS     = 25

  audioLeft = 11 
  audioRight= 10

  tvPin =  12
  
  

OBJ
fat : "SD-MMC_FATEngine"
tv: "TV_Text"

VAR

long sector_rq,sector_ack

byte buffer[1024]

PUB main
              
sector_ack := -1
decoderStart(audioLeft,audioRight)
if tvPin => 0
  tv.start(tvPin)
tv.str(string("HEPTAFON!",13))
fat.FATEngineStart(spiDO,spiClk,spiDI,spiCS,-1,-1,-1,-1,-1)  
fat.mountPartition(0)
fat.openFile(string("test.hep"),"r")

'fat.readData(@buffer,1024)
'tv.hex(long[@buffer+$68],8)

                      

repeat
  if sector_ack <> sector_rq
    ifnot fat.readData(@buffer+(sector_rq&1)<<9,512)
      tv.str(string("EOF",13))
      return
    sector_ack := sector_rq
    tv.dec(sector_ack)
    tv.out(13)



PRI decoderStart(left,right)

sampleCycles := clkfreq/32_000
sectorRqPtr := @sector_rq    
sectorAckPtr := @sector_ack
musicBufPtr := @buffer

tempValue1       := $18000000 | left
tempValue2       := $18000000 | right
tempValue3       := ((1 << right) | (1 << left)) & !1

cognew(@entry,0)


CON
PRED_SAMPLES = 3
SECTOR_UNITS = 35
UNIT_SAMPLES = 16
SECTOR_SAMPLES = SECTOR_UNITS*UNIT_SAMPLES+PRED_SAMPLES


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
              cmp sectorLeft,initThreshold wc
        if_b  jmp #:doDecode 
              cmp sectorLeft,sectorLength wz
        if_nz jmp #:no_ptrinit
              ' Check for ACK
              rdlong tempValue1,sectorAckPtr
              cmp tempValue1,sectorCurrent wz
        if_nz jmp #:doOutput ' panicc
              ' Init pointers
              mov uParPtr,musicBufPtr
              test sectorCurrent,#1 wz
        if_nz add uParPtr,bit9
              add uParPtr,#8 ' branch info (NYI)
              ' Prepare next
              mov sectorNext,sectorCurrent
              add sectorNext,#1
              wrlong sectorNext,sectorRqPtr
              ' Get sector parameter
              add uParPtr,#PRED_SAMPLES*4    
              rdword sectorPar,uParPtr   
              sub uParPtr,#PRED_SAMPLES*4              
:no_ptrinit
              rdlong musicOutX,uParPtr
              add uParPtr,#4
              mov musicOutY,musicOutX
              shl musicOutX,#16
              sar musicOutX,#16
              sar musicOutY,#16
              call #pushHistX
              call #pushHistY

              cmp sectorLeft,initThreshold wz         
        if_z  add uParPtr,#2
        if_z  mov uDatPtr,uParPtr
        if_z  add uDatPtr,#SECTOR_UNITS*2
              jmp #:sampleDone

:doDecode
              test sectorLeft,#15 wz
        if_nz jmp #:no_unitinit      
              rdlong slowData,uDatPtr
              add uDatPtr,#4  
              rdword unitPar,uParPtr
              add uParPtr,#2
              mov scaleX,unitPar
              and scaleX,#15   
              mov scaleY,unitPar
              shr scaleY,#4
              and scaleY,#15
              shr unitPar,#8
:no_unitinit
              test sectorLeft,#7 wz
        if_z  rdlong fastData,uDatPtr
        if_z  add uDatPtr,#4
              test sectorLeft,#8 wc
  if_c_and_z  mov tempValue1,unitPar
  if_c_and_z  shr tempValue1,#6  
  if_c_and_z  sub tempValue1,#2 
  if_c_and_z  add scaleX,tempValue1

              ' Generate predictions (unrolled because brrr)
              mov musicOutX,histX0    
              test unitPar,#%0001 wz         
        if_nz add musicOutX,musicOutX ' LINEAR or WEIGHTED
              test unitPar,#%0011 wc,wz
        if_nz sumc musicOutX,histX1 ' sub for LINEAR or QUADRATIC, add for WEIGHTED   
              test unitPar,#%0010 wz 
              mov tempValue2,musicOutX
              add tempValue2,musicOutX
  if_c_and_nz add musicOutX,tempValue2 ' QUADRATIC
        if_nz add musicOutX,histX2 ' QUADRATIC or WEIGHTED 
 if_nc_and_nz sar musicOutX,#2 ' WEIGHTED

              mov musicOutY,histY0    
              test unitPar,#%0100 wz         
        if_nz add musicOutY,musicOutY ' LINEAR or WEIGHTED
              test unitPar,#%1100 wc,wz
        if_nz sumc musicOutY,histY1 ' sub for LINEAR or QUADRATIC, add for WEIGHTED   
              test unitPar,#%1000 wz 
              mov tempValue2,musicOutY
              add tempValue2,musicOutY
  if_c_and_nz add musicOutY,tempValue2 ' QUADRATIC
        if_nz add musicOutY,histY2 ' QUADRATIC or WEIGHTED 
 if_nc_and_nz sar musicOutY,#2 ' WEIGHTED                                      
              
  
              test unitPar,#%10_0000 wz
        if_nz jmp #:subsampleMode
        
              test unitPar,#%1_0000 wz '  Z -> 6bit, NZ -> 3bit
              mov tempValue1,fastData
              shl fastData,#2
              shl slowData,#1 wc
        if_z  rcr tempValue1,#32-4 
        if_nz rcr tempValue1,#32-2   
              mov tempValue2,fastData  
              shl fastData,#2  
              shl slowData,#1 wc
              rcr tempValue2,#32-2
        if_z  muxc tempValue1,#16 

              ' X delta now in tempValue1, Y delta in tempValue2      
              shl tempValue1,scaleX
              cmps histX0,#0 wc        
              sumc musicOutX,tempValue1                     
              shl tempValue2,scaleY     
              cmps histY0,#0 wc        
        if_nz sumc musicOutY,tempValue2              
              call #pushHistX
              call #pushHistY
              
              jmp #:sampleDone


:subsampleMode                                                
                                       
              test unitPar,#%1_0000 wz ' Z -> Y subsampled, NZ -> X subsampled
        if_z  mov tempValue1,fastData  
        if_nz mov tempValue2,fastData     
        if_z  mov tempValue2,slowData 
        if_nz mov tempValue1,slowData
                                      
              sar tempValue1,#32-4
              sar tempValue2,#32-4
                                          
              ' X delta now in tempValue1, Y delta in tempValue2    
              shl tempValue1,scaleX
              cmps histX0,#0 wc        
              sumc musicOutX,tempValue1                     
              shl tempValue2,scaleY     
              cmps histY0,#0 wc        
              sumc musicOutY,tempValue2
                                                                                                       
              test sectorLeft,#1 wc ' set C for odd samples    
              shl fastData,#4 
        if_c  shl slowData,#4
   if_c_or_z  call #pushHistX
   if_c_or_nz call #pushHistY     
 if_nc_and_z  add musicOutY,histY0
 if_nc_and_z  sar musicOutY,#1   
 if_nc_and_nz add musicOutX,histX0
 if_nc_and_nz sar musicOutX,#1    
              

:sampleDone
              ' advance sectorLeft
              sub sectorLeft,#1 wz
        if_z  mov sectorLeft,sectorLength 
        if_z  mov sectorCurrent,sectorNext 


:doOutput
              ' Swap XY if need be
              test sectorPar,#|<0 wc 
        if_c  xor musicOutX,musicOutY
        if_c  xor musicOutY,musicOutX
        if_c  xor musicOutX,musicOutY
              ' Convert mid/side to left/right
              test sectorPar,#|<1 wc
              mov musicOutL,musicOutX
        if_nc add musicOutL,musicOutY
              negnc musicOutR,musicOutY
        if_nc add musicOutR,musicOutX
              ' clamp decoded values 
              mins musicOutL,clampMin
              maxs musicOutL,clampMax
              mins musicOutR,clampMin
              maxs musicOutR,clampMax

              ' do output             
              mov tempValue1,musicOutL 
              shl tempValue1,#15
              add tempValue1,bit31     
              mov tempValue2,musicOutR   
              shl tempValue2,#15  
              add tempValue2,bit31                     
              
              waitcnt cnt,sampleCycles
              mov frqa,tempValue1
              mov frqb,tempValue2           
              jmp #loop

pushHistX                      
              mov histX2,histX1
              mov histX1,histX0
              mov histX0,musicOutX
pushHistX_ret   
              ret

pushHistY                      
              mov histY2,histY1
              mov histY1,histY0
              mov histY0,musicOutY   
pushHistY_ret
              ret
              

bit31         long |<31       
bit9          long |<9
clampMin      long -$7FFF
clampMax      long  $7FFF
sectorLength  long SECTOR_SAMPLES
initThreshold long SECTOR_SAMPLES-PRED_SAMPLES+1

sectorCurrent long 0
sectorNext    long 0
sampleCycles  long 0
sectorRqPtr   long 0
sectorAckPtr  long 0
musicBufPtr   long 0
tempValue1    long 0
tempValue2    long 0
tempValue3    long 0   
tempValue4    long 0  
musicOutX     long 0 
musicOutY     long 0  

sectorPar     res 1
unitPar       res 1
sectorLeft    res 1
uparPtr       res 1
udatPtr       res 1
slowData      res 1
fastData      res 1   

scaleX        res 1
scaleY        res 1     
musicOutL     res 1
musicOutR     res 1

histX0        res 1 ' previous sample
histX1        res 1 ' the one before that
histX2        res 1 ' the one before that one
histY0        res 1
histY1        res 1
histY2        res 1

              fit 496
 