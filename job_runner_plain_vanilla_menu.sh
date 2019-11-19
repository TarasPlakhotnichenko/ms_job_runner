#!/bin/bash

#29/12/2018
#Plain vanilla job runner with menu
#Device is online, edit job if needed, init a randon volser, ebcdic encode, ftp upload for execution, view execution queue, tail bti log
#IN SD COMMAND INPUT: #/V &UNIT1,ONLINE    

#for i in `seq 0 9`
#do
#DEV='740'$i


#Edit this---vvvv
DEV="7400"         #DLm tape device
CLASS='0'          #Tapelib class
IP="10.246.139.64" #MF LPAR IP address
USERID="TPLAKH1"   #MF LPAR user id
#Edit this---^^^^

#-----------------------
#goto in bash to skip unwanted job definitions - thanks to https://bobcopeland.com/blog/2012/10/goto-in-bash/
function jumpto
{
    label=$1
    cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
    eval "$cmd"
    exit
}
start=${1:-"start"}
jumpto $start
start:
#-----------------------

RED='\033[0;31m'
NC='\033[0m'
echo -e "\nSure you varied the device online in terminal: ${RED}/V &UNIT,ONLINE${NC}"

#Init volser
VOL=DD`shuf -i 1000-9999 -n 1`
echo -e "Volume to write: ${RED}$VOL${NC} \n"
vtcmd --data "q dev=$DEV path"
echo -e "\n"
read -p "Press any key to continue... or ctrl+c to break " -n1 -s
echo -e "\n\n"
vtcmd --data "init dev=$DEV vol=$VOL count=1 class=$CLASS"
echo

#Simple menu------------
echo '---'
PS3='Please enter your choice: '
options=("Write a huge volume" "Write,Append,Read" "Scratch a tape" "Arbitrary job template" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Write a huge volume")
	    jumpto JOB1
            ;;
        "Write,Append,Read")
	    jumpto JOB2
            ;;
        "Scratch a tape")
	    jumpto JOB3
            ;;
        "Arbitrary job template")
        jumpto JOB4
           ;;	
        "Quit")
            exit
            ;;
        *) echo "invalid option $REPLY";;
    esac
done
#Simple menu------------


#vvvv=================JOB definitions=================vvvv

#------------------------------------------
#Writing a huge volume - set QUANTITY parameter.  For ex. setting 10000 resulted in ~8.5Mb disk space for the volume
JOB1:
cat <<EOF > /tmp/ascii.out
//$USERID  JOB (1),'$USERID',CLASS=A,NOTIFY=&SYSUID,REGION=0M        
// SET UNIT=$DEV
// SET VOL=$VOL                                                  
//*                                                                  
// SET COUNT=1                                                       
//IEBDG1   EXEC PGM=IEBDG                                            
//SYSPRINT DD SYSOUT=*                                               
//OUT      DD DSN=$USERID.TEST&UNIT,VOL=SER=&VOL,                        
//  DISP=(NEW,KEEP),DCB=(RECFM=FB,LRECL=800,BLKSIZE=800),UNIT=/&UNIT,
//     LABEL=(&COUNT,SL,RETPD=2)                                     
//SYSIN    DD *                                                      
   DSD OUTPUT=(OUT)                                                  
   FD NAME=FIELD1,LENGTH=10,FORMAT=AL,ACTION=RP                      
   FD NAME=FIELD2,LENGTH=3,PICTURE=3,'KIU'                           
   CREATE QUANTITY=1000,NAME=(FIELD1,FIELD2)                      
   END                                                               
/*                                                                   
//                                                                
EOF
jumpto FINISH
#------------------------------------------


#------------------------------------------
JOB2:
cat <<EOF > /tmp/ascii.out
//$USERID JOB (123),'$USERID',NOTIFY=&SYSUID,CLASS=A
//  SET UNIT=$DEV
//  SET VOL=$VOL
//*
//STEP1    EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=*
//SYSIN    DD DUMMY
//SYSUT1   DD *
WRITE DATA
00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000
/*
//SYSUT2   DD DSN=$USERID.TEST1,VOL=SER=&VOL,LABEL=(,SL),       
//            DISP=(NEW,KEEP),DCB=(RECFM=F,LRECL=80),UNIT=/&UNIT
/*
//STEP2 EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=*
//SYSIN DD DUMMY
//SYSUT1 DD *
APPEND DATA
11111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111
/*
//SYSUT2 DD DSN=$USERID.TEST1,VOL=SER=&VOL,
//          DISP=MOD,
//          UNIT=/&UNIT
/*
//STEP3 EXEC PGM=IEBGENER
//SYSPRINT DD SYSOUT=*
//SYSIN DD DUMMY
//SYSUT1 DD DSN=$USERID.TEST1,VOL=SER=&VOL,
//          DISP=SHR,UNIT=/&UNIT
//SYSUT2 DD SYSOUT=*
/*
EOF
jumpto FINISH
#------------------------------------------

#------------------------------------------
#Scratch a tape
JOB3:
echo -e "\nSure you varied the device offline in terminal: ${RED}/V &UNIT,OFFLINE${NC}"
read -p "Press any key to continue... or ctrl+c to break " -n1 -s
cat <<EOF > /tmp/ascii.out
//$USERID JOB (18132),'TPLAKH1',CLASS=A,NOTIFY=&SYSUID,REGION=0M
//  SET DEV=$DEV                                                
//  SET LINKLIB=EMC.DLMS453.LINKLIB                             
//*                                                             
//AUTH1    EXEC PGM=COMMAND,                                    
// PARM='SETPROG APF,ADD,DSN=&LINKLIB,SMS'                      
//SCR     EXEC PGM=DLMSCR,                                      
//  PARM='DEV=&DEV,TYPE=RMMDV,NODSNCHK,NODATECHK'               
//*PARM='DEV=&DEV,TYPE=RMMDV,NODSNCHK,NODATECHK'                
//*                                                             
//STEPLIB  DD  DISP=SHR,DSN=&LINKLIB                            
//DLMLOG   DD  SYSOUT=*                                         
//*LMSCR   DD  DISP=SHR,DSN=IKOVAL1.SCRATCH.REPORTS.SAMPLE(RMM) 
//DLMSCR   DD  *                                                
RMM DV $VOL FORCE
EOF
jumpto FINISH
#------------------------------------------



#------------------------------------------
#job definition template
JOB4:
cat <<EOF > /tmp/ascii.out
//$USERID JOB (18132),'TPLAKH1',CLASS=A,NOTIFY=&SYSUID,REGION=0M
//*
//
EOF
jumpto FINISH
#------------------------------------------


#^^^^=================JOB definitions=================^^^^


FINISH:
vi /tmp/ascii.out
#----------------
echo
read -p "Enter your MF password: " -s PSWD
ftp=$(lftp -e 'dir;bye' -u $USERID,$PSWD $IP)
if [[ $? -eq 0 ]]; then
  echo -e  "\nftp credentials: accepted"
else
  echo -e  "\nftp credentials: not accepted." 
  exit
fi
#----------------

dd status=none bs=10240 cbs=80 conv=ebcdic if=/tmp/ascii.out of=/tmp/ebcdic.out
echo -e "\nsite file=jes; put /tmp/ebcdic.out; bye' -u $USERID,XXXX $IP"
lftp -e 'site file=jes; put /tmp/ebcdic.out; bye' -u $USERID,$PSWD $IP
echo -e "\n"


read -p "Wait a bit to let things settle down... Press any key to continue" -n1 -s
echo -e "\nJob queue:\n"
JOB_QUEUE="$(lftp -e 'quote site filetype=jes; dir; bye' -u $USERID,$PSWD $IP)"
echo "${JOB_QUEUE}"


echo -e  "\n\nTailing btilog - /var/log/bti/btilog:\n"
sed -n "/init dev=$DEV vol=$VOL/,\$p" /var/log/bti/btilog
echo -e '---\n'
FIND_VOL=`/opt/bti/mas/bin/vtcmd --data "find vol=$VOL LOCAL"`
re='(\/[A-Za-z]+\/[A-Za-z_0-9]+)'
if [[ "${FIND_VOL}" =~ $re ]]; then
  TAPE="${BASH_REMATCH[0]}"\/"$VOL"
  AWSFLAT="awsflat "$TAPE" | dd status=none ibs=800 cbs=80 conv=ascii if=/dev/stdin of=/dev/stdout"
  AWSPRINT="awsprint -d ${BASH_REMATCH[0]} -s $VOL"
  AWSTEST="awstest $TAPE"
  AWSLIST="awslist $TAPE"
  AWSDATA="awsdata $TAPE /tmp/out.txt && cat /tmp/out.txt"
  
  echo -e "${RED}$AWSPRINT${NC}"
  echo -e "${RED}$AWSFLAT${NC}"
  echo -e "${RED}$AWSTEST${NC}"
  echo -e "${RED}$AWSLIST${NC}"
  echo -e "${RED}$AWSDATA${NC}"
 fi


#done

