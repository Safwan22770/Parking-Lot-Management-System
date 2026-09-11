.MODEL SMALL
.STACK 200H

.DATA

    MAXSLOT EQU 10
    MAXWAIT EQU 20
    MAXFARE EQU 150

    ; Fee is charged per minute parked.
    CARRATE  EQU 10
    BIKERATE EQU 5

    top      DB 0
    vehID    DW MAXSLOT DUP(0)

    ; Vehicle type:
    ; 1 = Car
    ; 2 = Bike
    vehType  DB MAXSLOT DUP(0)

    entryYear    DW MAXSLOT DUP(0)
    entryDOY     DW MAXSLOT DUP(0)
    entryMinute  DW MAXSLOT DUP(0)

    ; ---------- Waiting queue ----------
    waitID      DW MAXWAIT DUP(0)
    waitType    DB MAXWAIT DUP(0)
    waitHead    DB 0
    waitCount   DB 0

    ;
    ; Fare calculated for each exited vehicle is stored here.
    fareArray   DW MAXFARE DUP(0)
    fareCount   DW 0

    ; Revenue for the six months of the current
    ; six-month cycle.
    monthlyRevenue DW 6 DUP(0)

    currentCycle DB 0
    cycleStarted DB 0

    menuMsg     DB 13,10,'===== PARKING LOT MANAGEMENT SYSTEM =====',13,10
                DB '1. Park / Exit Vehicle',13,10
                DB '2. Search Vehicle by ID',13,10
                DB '3. Emergency Priority Exit',13,10
                DB '4. Exit Fee Calculation',13,10
                DB '5. Total Revenue Report',13,10
                DB '6. Capacity Report',13,10
                DB '7. Exit',13,10
                DB 'Enter your choice: $'

    parkExitPrompt DB 13,10,'1. Park Vehicle   2. Exit Vehicle : $'
    promptID       DB 13,10,'Enter Vehicle ID: $'

    vehicleTypeMsg DB 13,10,'Enter Vehicle Type (1=Car, 2=Bike): $'
    carMsg        DB 'Car$'
    bikeMsg       DB 'Bike$'

    lotFullMsg    DB 13,10,'Sorry, the lot is full. Vehicle will be added to waiting queue.',13,10,'$'
    waitingFullMsg DB 13,10,'Waiting queue is full. No more vehicles can wait.',13,10,'$'
    waitingAddedMsg DB 13,10,'Vehicle added to waiting queue.',13,10,'$'
    waitingAdmitMsg DB 13,10,'Waiting vehicle admitted. Vehicle ID: $'
    waitingSlotMsg DB '  Slot: $'

    parkedMsg     DB 13,10,'Vehicle parked at slot: $'
    lotEmptyMsg   DB 13,10,'The lot is currently empty.',13,10,'$'
    exitedMsg     DB 13,10,'Vehicle exited successfully. ID: $'
    blockedMsg1   DB 13,10,'Cannot exit yet - this vehicle is blocked.$'
    blockedMsg2   DB 13,10,'Vehicle ID $'
    blockedMsg3   DB ' is on top and must exit first.',13,10,'$'
    notFoundMsg   DB 13,10,'No vehicle with that ID is in the lot.',13,10,'$'
    invalidMsg    DB 13,10,'Invalid choice.',13,10,'$'
    duplicateMsg  DB 13,10,'That vehicle ID is already parked at slot: $'
    dupWaitMsg    DB 13,10,'That vehicle ID is already in the waiting queue.',13,10,'$'

    foundPosMsg   DB 13,10,'Vehicle found at slot: $'
    foundBlockMsg DB 13,10,'Vehicles blocking it (parked after it): $'

    emergencyMsg  DB 13,10,'Emergency exit granted. Vehicle ID $'
    emergencyMsg2 DB ' has left the lot.',13,10,'$'

    ; ---------- Fare messages ----------
    promptMinutes DB 13,10,'Parking time in minutes: $'
    feeMsg        DB 13,10,'Fee for this vehicle: $'
    takaMsg       DB ' Taka',13,10,'$'

    fareListMsg   DB 13,10,'Fare amounts collected: ',13,10,'$'
    fareItemMsg   DB ' Taka  $'

    ; ---------- Revenue messages ----------
    revenueMsg    DB 13,10,'Total Revenue Collected: $'
    previewNoteMsg DB '(Estimate only - not charged until the vehicle actually exits.)',13,10,'$'
    minuteMsg     DB 13,10,'Minute Revenue: $'
    minute1Msg    DB 13,10,'Minute 1: $'
    minute2Msg    DB 13,10,'Minute 2: $'
    minute3Msg    DB 13,10,'Minute 3: $'
    minute4Msg    DB 13,10,'Minute 4: $'
    minute5Msg    DB 13,10,'Minute 5: $'
    minute6Msg    DB 13,10,'Minute 6: $'

    warningMsg    DB 13,10,13,10
                  DB '*** WARNING ***',13,10
                  DB 'Revenue will reset soon.',13,10
                  DB 'Please note down the collected revenue.',13,10
                  DB 'Reset will occur after the six-month cycle.',13,10
                  DB '************************',13,10,'$'

    ; ---------- Capacity messages ----------
    totalCapMsg   DB 13,10,'Total Capacity : $'
    usedMsg       DB 13,10,'Occupied Slots : $'
    freeMsg       DB 13,10,'Free Slots     : $'
    waitingMsg    DB 13,10,'Waiting Vehicles: $'
    fullStatusMsg DB 13,10,'Status         : FULL',13,10,'$'
    openStatusMsg DB 13,10,'Status         : SPACE AVAILABLE',13,10,'$'

    ; ---------- Date/time support ----------
    monthDays DB 31,28,31,30,31,30,31,31,30,31,30,31


.CODE


PRINTSTR MACRO msg
    PUSH AX
    PUSH DX
    LEA  DX, msg
    MOV  AH, 09H
    INT  21H
    POP  DX
    POP  AX
ENDM


NEWLINE MACRO
    PUSH AX
    PUSH DX
    MOV  AH, 02H
    MOV  DL, 13
    INT  21H
    MOV  DL, 10
    INT  21H
    POP  DX
    POP  AX
ENDM

ReadNumber PROC
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  BX, 0

RN_LOOP:
    MOV  AH, 01H
    INT  21H

    CMP  AL, 13
    JE   RN_DONE

    CMP  AL, '0'
    JL   RN_LOOP

    CMP  AL, '9'
    JG   RN_LOOP

    SUB  AL, '0'
    MOV  AH, 0

    PUSH AX

    MOV  AX, BX
    MOV  CX, 10
    MUL  CX
    MOV  BX, AX

    POP  AX

    ADD  BX, AX
    JMP  RN_LOOP

RN_DONE:
    NEWLINE

    MOV  AX, BX

    POP  DX
    POP  CX
    POP  BX

    RET
ReadNumber ENDP

PrintNumber PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  CX, 0

    CMP  AX, 0
    JNE  PN_CONVERT

    MOV  DL, '0'
    MOV  AH, 02H
    INT  21H
    JMP  PN_END

PN_CONVERT:
    MOV  BX, 10

PN_DIVLOOP:
    CMP  AX, 0
    JE   PN_PRINTLOOP

    MOV  DX, 0
    DIV  BX

    PUSH DX
    INC  CX

    JMP  PN_DIVLOOP

PN_PRINTLOOP:
    CMP  CX, 0
    JE   PN_END

    POP  DX

    ADD  DL, '0'

    MOV  AH, 02H
    INT  21H

    DEC  CX
    JMP  PN_PRINTLOOP

PN_END:
    POP  DX
    POP  CX
    POP  BX
    POP  AX

    RET
PrintNumber ENDP

FindVehicle PROC
    PUSH AX
    PUSH BX

    MOV  AL, top
    MOV  AH, 0

    MOV  SI, 0

FV_LOOP:
    CMP  SI, AX
    JGE  FV_NOTFOUND

    MOV  BX, SI
    SHL  BX, 1

    CMP  vehID[BX], CX
    JE   FV_FOUND

    INC  SI
    JMP  FV_LOOP

FV_FOUND:
    CLC
    JMP  FV_DONE

FV_NOTFOUND:
    STC

FV_DONE:
    POP  BX
    POP  AX

    RET
FindVehicle ENDP

; Searches the circular waiting queue for a vehicle ID.
; In : CX = vehicle ID
; Out: CF clear = the ID is already waiting
;      CF set   = the ID is not in the queue
FindWaiting PROC
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI

    MOV  AL, waitCount
    MOV  AH, 0
    MOV  DX, AX                   ; DX = number of entries to check

    MOV  AL, waitHead
    MOV  AH, 0
    MOV  SI, AX                   ; SI = current queue slot

    MOV  BX, 0                    ; BX = entries checked so far

FW_LOOP:
    CMP  BX, DX
    JGE  FW_NOTFOUND

    PUSH BX

    MOV  BX, SI
    SHL  BX, 1
    MOV  AX, waitID[BX]

    POP  BX

    CMP  AX, CX
    JE   FW_FOUND

    ; advance, wrapping at the end of the queue
    INC  SI
    CMP  SI, MAXWAIT
    JL   FW_NEXT
    MOV  SI, 0

FW_NEXT:
    INC  BX
    JMP  FW_LOOP

FW_FOUND:
    CLC
    JMP  FW_DONE

FW_NOTFOUND:
    STC

FW_DONE:
    POP  SI
    POP  DX
    POP  BX
    POP  AX

    RET
FindWaiting ENDP

GetCurrentDateTime PROC

    PUSH DX
    PUSH SI
    PUSH DI

    ; Get date
    MOV  AH, 2AH
    INT  21H

    ; Save month and day
    MOV  DI, DX

    MOV  AL, DH
    MOV  AH, 0

    DEC  AX
    MOV  CX, AX

    MOV  BX, 0
    MOV  SI, 0

GCD_MONTH_LOOP:

    CMP  SI, CX
    JGE  GCD_MONTH_DONE

    MOV  AL, monthDays[SI]
    MOV  AH, 0

    ADD  BX, AX

    INC  SI
    JMP  GCD_MONTH_LOOP

GCD_MONTH_DONE:

    ; Add current day
    MOV  AL, DL
    MOV  AH, 0
    ADD  BX, AX

    MOV  AH, 2CH
    INT  21H

    ; CH = hour
    ; CL = minute

    MOV  AL, CH
    MOV  AH, 0

    MOV  SI, 60
    MUL  SI

    MOV  DX, AX

    MOV  AL, CL
    MOV  AH, 0

    ADD  AX, DX

    MOV  CX, AX

    ; Save the minutes value before the next INT 21h call
    ; overwrites CX - this is the fix: previously CX was left
    ; holding the year (from the call below) instead of the
    ; minutes computed just above.
    PUSH CX

    ; Get year again
    MOV  AH, 2AH
    INT  21H

    MOV  AX, CX

    ; Restore CX = minutes since midnight
    POP  CX

    POP  DI
    POP  SI
    POP  DX

    RET
GetCurrentDateTime ENDP

StoreEntryTime PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    CALL GetCurrentDateTime

    ; AX = year
    ; BX = day of year
    ; CX = minutes since midnight

    MOV  DI, SI
    SHL  DI, 1

    MOV  entryYear[DI], AX
    MOV  entryDOY[DI], BX
    MOV  entryMinute[DI], CX

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX

    RET
StoreEntryTime ENDP

;  CalculateParkingMinutes

CalculateParkingMinutes PROC

    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI

    ; Get current date/time
    CALL GetCurrentDateTime
    ; AX = year
    ; BX = current day of year
    ; CX = current minutes

    MOV  DI, SI
    SHL  DI, 1

    ; --------------------------------
    ; Compare years
    ; --------------------------------

    CMP  AX, entryYear[DI]
    JE   CPM_SAME_YEAR

    MOV  AX, 201
    JMP  CPM_DONE

CPM_SAME_YEAR:

    MOV  DX, BX
    SUB  DX, entryDOY[DI]

    CMP  DX, 0
    JE   CPM_SAME_DAY

    CMP  DX, 1
    JE   CPM_NEXT_DAY

    MOV  AX, 201
    JMP  CPM_DONE


CPM_SAME_DAY:

    MOV  AX, CX
    SUB  AX, entryMinute[DI]

    JMP  CPM_DONE


CPM_NEXT_DAY:

    MOV  AX, 1440
    SUB  AX, entryMinute[DI]
    ADD  AX, CX

CPM_DONE:

    POP  DI
    POP  DX
    POP  CX
    POP  BX

    RET
CalculateParkingMinutes ENDP


ParkExitVehicle PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI
    PUSH DI

    PRINTSTR parkExitPrompt

    CALL ReadNumber

    CMP  AX, 1
    JE   PE_PARK

    CMP  AX, 2
    JE   PE_EXIT_CHOICE

    PRINTSTR invalidMsg
    JMP  PE_DONE


PE_PARK:

    MOV  AL, top
    CMP  AL, MAXSLOT
    JB   PE_ROOM                  ; unsigned compare - MAXSLOT will not fit a signed byte if raised above 127


    PRINTSTR lotFullMsg

    MOV  AL, waitCount
    CMP  AL, MAXWAIT
    JGE  PE_WAIT_FULL

    PRINTSTR promptID
    CALL ReadNumber

    MOV  CX, AX

    ; An ID already in the system cannot be entered again.
    CALL FindVehicle
    JC   PE_WAIT_CHECK_QUEUE

    PRINTSTR duplicateMsg
    MOV  AX, SI
    INC  AX
    CALL PrintNumber
    NEWLINE
    JMP  PE_DONE

PE_WAIT_CHECK_QUEUE:

    CALL FindWaiting
    JC   PE_WAIT_ID_OK

    PRINTSTR dupWaitMsg
    JMP  PE_DONE

PE_WAIT_ID_OK:

    PRINTSTR vehicleTypeMsg
    CALL ReadNumber

    MOV  BX, AX                   ; BX = vehicle type, kept safe

    ; work out this vehicle's slot in the circular waiting queue
    MOV  AL, waitCount
    MOV  AH, 0

    MOV  SI, AX

    MOV  AL, waitHead
    MOV  AH, 0

    ADD  AX, SI

    CMP  AX, MAXWAIT
    JL   PE_QUEUE_INDEX_DONE

    SUB  AX, MAXWAIT

PE_QUEUE_INDEX_DONE:

    MOV  SI, AX

    MOV  DI, SI
    SHL  DI, 1

    MOV  waitID[DI], CX
    MOV  waitType[SI], BL

    INC  waitCount

    PRINTSTR waitingAddedMsg
    JMP  PE_DONE


PE_WAIT_FULL:

    PRINTSTR waitingFullMsg
    JMP  PE_DONE


PE_ROOM:

    PRINTSTR promptID
    CALL ReadNumber

    MOV  CX, AX

    ; An ID already in the system cannot be entered again.
    CALL FindVehicle
    JC   PE_ROOM_CHECK_QUEUE

    PRINTSTR duplicateMsg
    MOV  AX, SI
    INC  AX
    CALL PrintNumber
    NEWLINE
    JMP  PE_DONE

PE_ROOM_CHECK_QUEUE:

    CALL FindWaiting
    JC   PE_ROOM_ID_OK

    PRINTSTR dupWaitMsg
    JMP  PE_DONE

PE_ROOM_ID_OK:

    PRINTSTR vehicleTypeMsg
    CALL ReadNumber

    ; AX = vehicle type
    MOV  BX, AX

    ; Store vehicle ID
    MOV  AL, top
    MOV  AH, 0

    MOV  SI, AX
    SHL  SI, 1

    MOV  vehID[SI], CX

    ; Store vehicle type
    MOV  AL, top
    MOV  AH, 0

    MOV  SI, AX
    MOV  vehType[SI], BL

    ; Store entry time
    MOV  AL, top
    MOV  AH, 0

    MOV  SI, AX

    CALL StoreEntryTime

    INC  top

    PRINTSTR parkedMsg

    MOV  AL, top
    MOV  AH, 0

    CALL PrintNumber

    NEWLINE

    JMP  PE_DONE


PE_EXIT_CHOICE:

    MOV  AL, top
    CMP  AL, 0
    JNE  PE_ECONT

    PRINTSTR lotEmptyMsg
    JMP  PE_DONE


PE_ECONT:

    PRINTSTR promptID

    CALL ReadNumber

    MOV  CX, AX

    CALL FindVehicle

    JC   PE_NOTFOUND

    MOV  AL, top
    MOV  AH, 0

    DEC  AX

    CMP  SI, AX
    JE   PE_ONTOP

    JMP  PE_BLOCKED


PE_ONTOP:

    MOV  BX, 1                     ; BX=1: this is a real exit, commit the charge
    CALL CalculateAndCollectFare

    DEC  top

    PRINTSTR exitedMsg

    MOV  AX, CX
    CALL PrintNumber

    NEWLINE

    ; Admit first waiting vehicle
    CALL AdmitWaitingVehicle

    JMP  PE_DONE


PE_BLOCKED:

    PRINTSTR blockedMsg1
    PRINTSTR blockedMsg2

    MOV  AL, top
    MOV  AH, 0

    DEC  AX

    MOV  BX, AX
    SHL  BX, 1

    MOV  AX, vehID[BX]

    CALL PrintNumber

    PRINTSTR blockedMsg3

    JMP  PE_DONE


PE_NOTFOUND:

    PRINTSTR notFoundMsg


PE_DONE:

    POP  DI
    POP  SI
    POP  CX
    POP  BX
    POP  AX

    RET
ParkExitVehicle ENDP

SearchVehicle PROC
    PUSH AX
    PUSH CX
    PUSH SI

    MOV  AL, top
    CMP  AL, 0
    JNE  SV_CONTINUE

    PRINTSTR lotEmptyMsg
    JMP  SV_EXIT


SV_CONTINUE:

    PRINTSTR promptID

    CALL ReadNumber

    MOV  CX, AX

    CALL FindVehicle

    JC   SV_NOTFOUND

    PRINTSTR foundPosMsg

    MOV  AX, SI
    INC  AX

    CALL PrintNumber

    PRINTSTR foundBlockMsg

    MOV  AL, top
    MOV  AH, 0

    DEC  AX

    SUB  AX, SI

    CALL PrintNumber

    NEWLINE

    JMP  SV_EXIT


SV_NOTFOUND:

    PRINTSTR notFoundMsg


SV_EXIT:

    POP  SI
    POP  CX
    POP  AX

    RET
SearchVehicle ENDP

EmergencyPriorityExit PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI
    PUSH DI

    MOV  AL, top
    CMP  AL, 0
    JNE  EP_CONTINUE

    PRINTSTR lotEmptyMsg
    JMP  EP_EXIT


EP_CONTINUE:

    PRINTSTR promptID

    CALL ReadNumber

    MOV  CX, AX

    CALL FindVehicle

    JC   EP_NOTFOUND

    PRINTSTR emergencyMsg

    MOV  AX, CX

    CALL PrintNumber

    PRINTSTR emergencyMsg2

    MOV  BX, 1                     ; BX=1: this is a real exit, commit the charge
    CALL CalculateAndCollectFare


EP_SHIFTLOOP:

    MOV  AL, top
    MOV  AH, 0

    DEC  AX

    CMP  SI, AX
    JGE  EP_SHIFTDONE


    MOV  BX, SI
    SHL  BX, 1

    MOV  AX, vehID[BX+2]
    MOV  vehID[BX], AX

    MOV  AL, vehType[SI+1]
    MOV  vehType[SI], AL


    MOV  DI, SI
    SHL  DI, 1

    MOV  AX, entryYear[DI+2]
    MOV  entryYear[DI], AX

    MOV  AX, entryDOY[DI+2]
    MOV  entryDOY[DI], AX

    MOV  AX, entryMinute[DI+2]
    MOV  entryMinute[DI], AX

    INC  SI

    JMP  EP_SHIFTLOOP


EP_SHIFTDONE:

    DEC  top

    CALL AdmitWaitingVehicle

    JMP  EP_EXIT


EP_NOTFOUND:

    PRINTSTR notFoundMsg


EP_EXIT:

    POP  DI
    POP  SI
    POP  CX
    POP  BX
    POP  AX

    RET
EmergencyPriorityExit ENDP

;  AdmitWaitingVehicle

AdmitWaitingVehicle PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    MOV  AL, waitCount
    CMP  AL, 0
    JE   AWV_DONE

    MOV  AL, waitHead
    MOV  AH, 0

    MOV  SI, AX

    MOV  DI, SI
    SHL  DI, 1

    MOV  CX, waitID[DI]

    ; Get type
    MOV  BL, waitType[SI]


    MOV  AL, top
    MOV  AH, 0

    MOV  SI, AX

    MOV  DI, SI
    SHL  DI, 1

    MOV  vehID[DI], CX

    MOV  vehType[SI], BL

    CALL StoreEntryTime

    INC  top

    ; Remove from  queue

    INC  waitHead

    MOV  AL, waitHead
    CMP  AL, MAXWAIT
    JL   AWV_HEAD_OK

    MOV  waitHead, 0

AWV_HEAD_OK:

    DEC  waitCount

    PRINTSTR waitingAdmitMsg

    MOV  AX, CX
    CALL PrintNumber

    PRINTSTR waitingSlotMsg

    MOV  AL, top
    MOV  AH, 0

    CALL PrintNumber

    NEWLINE


AWV_DONE:

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX

    RET
AdmitWaitingVehicle ENDP

;  CalculateAndCollectFare


CalculateAndCollectFare PROC

    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ; SI = vehicle index

    CALL CalculateParkingMinutes

    ; AX = parking minutes

    MOV  DX, AX


    MOV  AL, vehType[SI]
    MOV  AH, 0

    CMP  AX, 1
    JE   CF_CAR

    CMP  AX, 2
    JE   CF_BIKE

    ; Unknown type - charged at the car rate
    MOV  CX, CARRATE
    JMP  CF_CHARGE


CF_CAR:

    MOV  CX, CARRATE
    JMP  CF_CHARGE


CF_BIKE:

    MOV  CX, BIKERATE


CF_CHARGE:

    ; Fee = minutes parked * per-minute rate.
    ; DX holds the minutes and is still needed for the
    ; display below, so it is saved across the MUL.

    MOV  AX, DX

    CMP  AX, 0
    JNE  CF_MULTIPLY

    ; Anything under a full minute is billed as one minute.
    MOV  AX, 1

CF_MULTIPLY:

    PUSH DX

    MUL  CX

    POP  DX


CF_STORE:


    PUSH AX

    ; Display parking minutes
    PRINTSTR promptMinutes

    MOV  AX, DX
    CALL PrintNumber

    PRINTSTR feeMsg

    POP  AX

    ; Save fare temporarily
    PUSH AX

    CALL PrintNumber

    PRINTSTR takaMsg

    POP  AX

    ; BX = 1 for a real exit (commit the charge), BX = 0 for a
    ; preview-only call (just show the fee, don't record it) -
    ; this is what stops "Exit Fee Calculation" from charging a
    ; vehicle that hasn't actually left the lot yet.
    CMP  BX, 0
    JE   CF_PREVIEW_ONLY

    MOV  BX, fareCount
    CMP  BX, MAXFARE
    JGE  CF_NO_FARE_STORAGE

    MOV  DI, BX
    SHL  DI, 1

    MOV  fareArray[DI], AX

    INC  fareCount


CF_NO_FARE_STORAGE:

    ; Add fare to current monthly
    ; revenue.


    PUSH AX

    CALL UpdateMonthlyRevenue

    POP  AX

    JMP  CF_DONE


CF_PREVIEW_ONLY:

    PRINTSTR previewNoteMsg


CF_DONE:

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX

    RET
CalculateAndCollectFare ENDP


UpdateMonthlyRevenue PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    PUSH AX

    ; Get current date
    MOV  AH, 2AH
    INT  21H

    ; DH = month
    ; DL = day

    MOV  AL, DH
    MOV  AH, 0

    ; Determine cycle
    CMP  AL, 7
    JL   UMR_FIRST_CYCLE

    MOV  BL, 1
    JMP  UMR_CYCLE_READY


UMR_FIRST_CYCLE:

    MOV  BL, 0


UMR_CYCLE_READY:


    CMP  cycleStarted, 0
    JE   UMR_FIRST_START

    CMP  BL, currentCycle
    JE   UMR_SAME_CYCLE
    
    ; Six months completed.


    CALL ResetRevenueArray

    MOV  currentCycle, BL

    JMP  UMR_SAME_CYCLE


UMR_FIRST_START:

    MOV  currentCycle, BL
    MOV  cycleStarted, 1

    CALL ResetRevenueArray


UMR_SAME_CYCLE:

    ; Calculate month index.

    MOV  AL, DH
    MOV  AH, 0

    CMP  AL, 7
    JL   UMR_JAN_JUNE

    SUB  AX, 7
    JMP  UMR_INDEX_READY


UMR_JAN_JUNE:

    DEC  AX


UMR_INDEX_READY:

    MOV  SI, AX

    SHL  SI, 1

    POP  AX

    ADD  monthlyRevenue[SI], AX

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX

    RET

UpdateMonthlyRevenue ENDP

;  Clears all six monthly revenue entries.

ResetRevenueArray PROC

    PUSH AX
    PUSH CX
    PUSH DI

    MOV  CX, 6
    MOV  DI, 0

RRA_LOOP:

    MOV  monthlyRevenue[DI], 0

    ADD  DI, 2

    LOOP RRA_LOOP

    ; Keep the fare history list in sync with the reset revenue -
    ; otherwise "Fare amounts collected" keeps growing forever
    ; while "Total Revenue Collected" resets every six months,
    ; and the two numbers stop matching each other.
    MOV  fareCount, 0

    POP  DI
    POP  CX
    POP  AX

    RET
ResetRevenueArray ENDP

TotalRevenueReport PROC

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    
    ; Warning during June 10-15


    MOV  AH, 2AH
    INT  21H

    CMP  DH, 6
    JNE  TR_NO_WARNING

    CMP  DL, 10
    JL   TR_NO_WARNING

    CMP  DL, 15
    JG   TR_NO_WARNING

    PRINTSTR warningMsg


TR_NO_WARNING:

    ; Display fare array

    PRINTSTR fareListMsg

    MOV  CX, fareCount
    MOV  SI, 0

TR_FARE_LOOP:

    CMP  SI, CX
    JGE  TR_FARE_DONE

    MOV  DI, SI
    SHL  DI, 1

    MOV  AX, fareArray[DI]

    CALL PrintNumber

    PRINTSTR fareItemMsg

    INC  SI

    JMP  TR_FARE_LOOP


TR_FARE_DONE:

    NEWLINE

    ; Calculate total revenue

    PRINTSTR revenueMsg

    MOV  CX, 6
    MOV  SI, 0
    MOV  BX, 0

TR_TOTAL_LOOP:

    MOV  AX, monthlyRevenue[SI]

    ADD  BX, AX

    ADD  SI, 2

    LOOP TR_TOTAL_LOOP

    MOV  AX, BX

    CALL PrintNumber

    PRINTSTR takaMsg

    ; Display individual months

    PRINTSTR minuteMsg


    PRINTSTR minute1Msg

    MOV  AX, monthlyRevenue[0]
    CALL PrintNumber
    PRINTSTR takaMsg


    PRINTSTR minute2Msg

    MOV  AX, monthlyRevenue[2]
    CALL PrintNumber
    PRINTSTR takaMsg


    PRINTSTR minute3Msg

    MOV  AX, monthlyRevenue[4]
    CALL PrintNumber
    PRINTSTR takaMsg


    PRINTSTR minute4Msg

    MOV  AX, monthlyRevenue[6]
    CALL PrintNumber
    PRINTSTR takaMsg


    PRINTSTR minute5Msg

    MOV  AX, monthlyRevenue[8]
    CALL PrintNumber
    PRINTSTR takaMsg


    PRINTSTR minute6Msg

    MOV  AX, monthlyRevenue[10]
    CALL PrintNumber
    PRINTSTR takaMsg


    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX

    RET
TotalRevenueReport ENDP


CapacityReport PROC

    PUSH AX
    PUSH BX

    PRINTSTR totalCapMsg

    MOV  AX, MAXSLOT

    CALL PrintNumber


    PRINTSTR usedMsg

    MOV  AL, top
    MOV  AH, 0

    CALL PrintNumber


    PRINTSTR freeMsg

    MOV  AX, MAXSLOT

    MOV  BL, top
    MOV  BH, 0

    SUB  AX, BX

    CALL PrintNumber


    PRINTSTR waitingMsg

    MOV  AL, waitCount
    MOV  AH, 0

    CALL PrintNumber


    MOV  AL, top
    CMP  AL, MAXSLOT
    JB CR_OPEN

    PRINTSTR fullStatusMsg

    JMP  CR_EXIT


CR_OPEN:

    PRINTSTR openStatusMsg


CR_EXIT:

    POP  BX
    POP  AX

    RET
CapacityReport ENDP


ExitFeeCalculation PROC

    PUSH AX
    PUSH CX
    PUSH SI

    MOV  AL, top
    CMP  AL, 0
    JNE  EF_CONTINUE

    PRINTSTR lotEmptyMsg

    JMP  EF_EXIT


EF_CONTINUE:

    PRINTSTR promptID

    CALL ReadNumber

    MOV  CX, AX

    CALL FindVehicle

    JC   EF_NOTFOUND

    ; SI contains vehicle index.

    MOV  BX, 0                     ; BX=0: preview only, don't charge yet
    CALL CalculateAndCollectFare

    JMP  EF_EXIT


EF_NOTFOUND:

    PRINTSTR notFoundMsg


EF_EXIT:

    POP  SI
    POP  CX
    POP  AX

    RET
ExitFeeCalculation ENDP


MAIN PROC

    MOV  AX, @DATA
    MOV  DS, AX


MENU_LOOP:

    PRINTSTR menuMsg

    CALL ReadNumber

    CMP  AX, 1
    JE   DO_PARKEXIT

    CMP  AX, 2
    JE   DO_SEARCH

    CMP  AX, 3
    JE   DO_EMERGENCY

    CMP  AX, 4
    JE   DO_FEE

    CMP  AX, 5
    JE   DO_REVENUE

    CMP  AX, 6
    JE   DO_CAPACITY

    CMP  AX, 7
    JE   DO_EXIT

    PRINTSTR invalidMsg

    JMP  MENU_LOOP


DO_PARKEXIT:

    CALL ParkExitVehicle

    JMP  MENU_LOOP


DO_SEARCH:

    CALL SearchVehicle

    JMP  MENU_LOOP


DO_EMERGENCY:

    CALL EmergencyPriorityExit

    JMP  MENU_LOOP


DO_FEE:

    CALL ExitFeeCalculation

    JMP  MENU_LOOP


DO_REVENUE:

    CALL TotalRevenueReport

    JMP  MENU_LOOP


DO_CAPACITY:

    CALL CapacityReport

    JMP  MENU_LOOP


DO_EXIT:

    MOV  AH, 4CH
    INT  21H


MAIN ENDP

END MAIN