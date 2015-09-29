#!/bin/bash
/bin/date
conf_dir="/etc/backupit/servers/"
backup_dir="/data0/"
date_file=$(date +%d-%m-%Y)
log_dir="/var/log/backupit"
start_task=$(date +%s)
imggogol=( "cid:coabawkodo" "cid:ttayvjebpl" )


function putlog () {

        case "$1" in

                HEADER)
                        mail+='<table>
  <tr style="color: #000000;background: #CCCCCC;">
    <th align="left" style="padding:5px 5px 5px 5px;">État</th>
    <th align="left" style="padding:5px 5px 5px 5px;">Serveur</th>
    <th align="left" style="padding:5px 5px 5px 5px;">Type</th>
    <th align="left" style="padding:5px 5px 5px 5px;">Début</th>
    <th align="left" style="padding:5px 5px 5px 5px;">Fin</th>
    <th align="left" style="padding:5px 5px 5px 5px;">Durée</th>
    <th align="left" style="padding:5px 5px 5px 5px;">Taille</th>
    <th align="left" style="padding:5px 5px 5px 5px;">Vitesse</th>
    <th align="left" style="padding:5px 5px 5px 5px;">Logs</th></tr>' ;;


                FOOTER)
                        mail+='  </tr></table></div></body></html>' ;;

                *)
                        mail+=' <tr style="color: #000000;background: #FFFF99;">
   <td style="padding:5px 5px 5px 5px;">'"$1"'</td>
   <td style="padding:5px 5px 5px 5px;">'"$2"'</td>
   <td style="padding:5px 5px 5px 5px;">'"$3"'</td>
   <td style="padding:5px 5px 5px 5px;">'"$4"'</td>
   <td style="padding:5px 5px 5px 5px;">'"$5"'</td>
   <td style="padding:5px 5px 5px 5px;">'"$6"'</td>
   <td style="padding:5px 5px 5px 5px;">'"$7"'</td>
   <td style="padding:5px 5px 5px 5px;">'"$8"'</td>
   <td style="padding:5px 5px 5px 5px;">'"$9"'</td>
  </tr>' ;;

        esac
}



start_time() {
        T=`date +%s`
        TSTR=$(date +%H:%M:%S)
}

stop_time() {
        ((SEC=`date +%s`-T,S=SEC,H=S/3600,S=S%3600,M=S/60,S=S%60));((!H||H<=9))&&H=0$H;((!M||M<=9))&&M=0$M;((!S||S<=9))&&S=0$S
        time_str="$H:$M:$S"
        TSTR2=$(date +%H:%M:%S)

}


# recupere le volume groupe d'un block device lvm
extract_vg () {
        vg_array=( ${lvm_part//\// } )
        vg=${vg_array[1]}
}

# demount/supprime le snap si existant
remove_snap () {

        echo "|_ Umounting/removing snap "
        ssh -n -c blowfish root@$1 "a=( \`mount\` );[[ \${a[*]} =~ backupit ]] && umount -fl /backupit 1>&2
                               b=( \`lvs\` );[[ \${b[*]} =~ backupit ]] && lvremove -f /dev/$vg/backupit 1>&2" 2>> $log_name

}

remove_snap_local () {
        echo "|_ Umounting/removing snap "
        a=( `mount` );[[ ${a[*]} =~ backupit ]] && umount -fl /backupit 1>&2 2>> $log_name
        b=( `lvs` );[[ ${b[*]} =~ backupit ]] && lvremove -f /dev/$vg/backupit 1>&2 2>> $log_name
}


# genere une URL rsync selon le protocol.
check_rsync_proto () {


        if [[ "$protocol" == "rsync" ]]; then
                login_url="rsync://${hostname}/root${backup}"
                echo "login url => $login_url"
#               exit
                ssh_url=""
        elif [[ "$protocol" == "ssh" ]]; then
                login_url="root@${hostname}:${backup}"
                ssh_url="ssh -p ${port} -ax -c blowfish -o compression=no"
        else
                login_url="${backup}"
                ssh_url=""
        fi

}

# Verifie si rsync/ssh sont fonctionnel sur la machine (test avec un transfert de fichier)
check_rsync_ok () {
        fail=0
        echo -n "|_ Checking rsync/ssh connectivity/transfer "
        random_check=$RANDOM

        if [[ !$xenhost ]]; then
                serv_list="$hostname"
        else
                if [[ $hostname == $xenhost ]]; then
                        serv_list="$hostname"
                else
                        serv_list="$hostname $xenhost"
                fi
        fi

        for serv in $serv_list; do
                if [[ $serv ]]; then

                        echo -n " ($serv)ssh:"
                        checking=$(ssh -p ${port} -n -c blowfish root@${serv} "echo $random_check")
                        if [[ $checking != $random_check ]]; then
                                echo -n "fail,"
                                fail=1
                                break
                        else
                                echo -n "ok,"
                        fi

                        echo -n "rsync:"
                        echo $random_check > /dev/shm/$random_check

                        login_url="root@${serv}:${backup}"
                        [[ $protocol =~ rsync ]] && login_url="rsync://${hostname}/root${backup}"
                        [[ $ip -eq 6 && $protocol =~ rsync ]] && login_url="rsync://[${hostname}]/root${backup}"
                        [[ $ip -eq 6 && $protocol =~ ssh ]] && login_url="root@[${serv}]:${backup}"


                        if [[ $devcheck -eq 1 ]]; then
                        rsync -vP -e  "$ssh_url" --numeric-ids --no-human-readable -a \
                                                                        $inc_exclude  \
                                                                        -$ip $bw      \
                                                                        --delete      \
                          /dev/shm/$random_check $login_url  1>>$log_name 2>>$log_name


                        rsync -vP -e "$ssh_url" --numeric-ids --no-human-readable -a \
                                                                $inc_exclude \
                                                                        -$ip $bw     \
                                                                        --delete     \
                 ${login_url}${random_check} /dev/shm/$random_check.ok  1>>$log_name 2>>$log_name



                        if [[ $(cat /dev/shm/$random_check) == $(cat /dev/shm/$random_check.ok) ]]; then
                                echo -n "ok "
                                rm -rf /dev/shm/$random_check
                                ssh root@${serv} "rm $backup/$random_check"
                                rm -rf /dev/shm/$random_check.ok
                        else
                                fail=1
                                echo -n "fail "
                                rm -rf /dev/shm/$random_check
                                break
                        fi

                        else

                                fail=0
                        fi

                fi
        done
        echo
        result=$fail
}


inc_rsync () {

        echo "inc_rsync realpath : $realpath"

        if [[ "$exclude" == "none" ]]; then
                inc_exclude=""
        else
                inc_exclude="--exclude ${exclude//,/ --exclude }"
        fi



        if [[ $ip -ne 4 && $ip -ne 6 ]]; then
                ip=4
        fi


        if [[ $bandwidth -eq 0 ]]; then
                bw=""
        else
                bw="--bwlimit $bandwidth"
        fi

        check_rsync_proto

        if [[ "$protocol" == "rsync" || "$protocol" == "ssh" ]]; then
                check_rsync_ok
        fi

        echo -n "|_ Doing rsync "



        if [[ $result -eq 0 ]]; then

                for i in `eval echo {0..$retention}`; do
                        [[ ! -d backup.$i ]] && mkdir -p backup.$i 1>/dev/null 2>/dev/null
                done

                [[ -d backup.$retention ]] && /bin/rm -rf backup.$retention > /dev/null

                for i in `eval echo {$retention..1}`; do
                        dir_tmp=backup.$[${i}-1]
                       [[ -d $dir_tmp ]] &&  /bin/mv $dir_tmp backup.${i} 1>/dev/null 2>/dev/null
                done
                rsync -e "$ssh_url" --numeric-ids --stats --no-human-readable -a             \
                                                                    $inc_exclude             \
                                                                    -$ip $bw                 \
                                                                    --delete                 \
                                                                    --link-dest=../backup.1  \
                                                            $login_url               \
                                                            backup.0/ 1>>$log_name 2>>$log_name
                ret=$?
           ### DEBUG ###
           echo "### DEBUG ###"
           echo "ssh_url  => $ssh_url"
           echo "login_url=> $login_url"
           echo "### DEBUG ###"
                echo "return code => $ret" 1>>$log_name 2>>$log_name

                stop_time

                if [[ $ret -eq 24 || $ret -eq 23 || $ret -eq 0 ]]; then

                        while read line; do

                                line_array=( $line )

                                [[ $line =~ Number\ of\ regular\ files\ transferred ]] && file_transfered=${line_array[5]}
                                [[ $line =~ Total\ transferred\ file\ size ]] && tot_size=${line_array[4]}

                        done < $log_name

                        ((tot_size=tot_size/1024/1024))
                        ((mega_tot_MB=mega_tot_MB+tot_size))
                        ((mega_file_transfered=mega_file_transfered+file_transfered))

                        bandwidth=$(echo "scale=2;$tot_size/$SEC"|bc)
                        stat_str="[ +"$tot_size"MB (+$file_transfered Files) in "$time_str"s at "$bandwidth"MB/s ]"

                        echo "[OK] $stat_str"
                else
                        FFFAIL=1
                        echo '[FAILED]'
                fi

                [[ -d $dest/backup.0 ]] && chmod 777 $dest/backup.0 && echo $date_file > backup.0/BACKUP_DATE.txt

        else
                FFFAIL=1
                echo "[FAILED]"
        fi

}


# methode LVM mysql
mysql_LVM () {
        echo "realpath => $realpath"
        start_time
        extract_vg

        echo -n "|_ Starting Backup of [$name] (locking tables + snap) "

        ssh -n -c blowfish root@$hostname "a=( \`mount\` );[[ \${a[*]} =~ backupit ]] && umount -fl /backupit 1>&2
                                           b=( \`lvs\` );[[ \${b[*]} =~ backupit ]] && lvremove -f /dev/$vg/backupit 1>&2
                                           mysql -u$mysql_user -p$mysql_pass -e 'flush tables with read lock;
                                                                                 system lvcreate -s $lvm_part -n backupit -L$lvsize 1>&2;
                                                                                 unlock tables;'
                                           [[ ! -d backupit ]] && mkdir -p /backupit 1>&2;mount /dev/$vg/backupit /backupit 1>&2 && echo '[OK]' || echo '[FAILED]'" 2>>$log_name
        [[ $realpath =~ ^\. ]] && unset realpath
        backup=/backupit/$realpath
        inc_rsync
        remove_snap $hostname
}


# methode recuperation de fichiers
data_rsync_XEN () {

        start_time
        extract_vg

        echo -n "|_ Starting Backup of [guest=>$name on $xenhost] (creating snap) "
        ssh -n -c blowfish root@$xenhost "a=( \`mount\` );[[ \${a[*]} =~ backupit ]] && umount -fl /backupit 1>&2
                                          b=( \`lvs\` );[[ \${b[*]} =~ backupit ]] && lvremove -f /dev/$vg/backupit 1>&2
                                          lvcreate -s $lvm_part -n backupit -L$lvsize 1>&2
                                          [[ ! -d backupit ]] && mkdir -p /backupit 1>&2
                                          mount /dev/$vg/backupit /backupit 1>&2 && echo '[OK]' || echo '[FAILED]'" 2>> $log_name
        backup=/backupit/
        hostname=$xenhost
        inc_rsync
        remove_snap $xenhost

}


data_rsync_lvm_local () {

        start_time
        extract_vg

        echo -n "|_ Starting Backup of [guest=>$name on localstorage] (creating snap) "

        a=( `mount` );[[ ${a[*]} =~ backupit ]] && umount -fl /backupit 1>&2 2>> $log_name
        b=( `lvs` );[[ ${b[*]} =~ backupit ]] && lvremove -f /dev/$vg/backupit 1>&2 2>> $log_name
        lvcreate -s $lvm_part -n backupit -L$lvsize >&$log_name
        [[ ! -d backupit ]] && mkdir -p /backupit 1>&2 2>> $log_name
        mount /dev/$vg/backupit /backupit 1>&2 && echo '[OK]' || echo '[FAILED]' 2>> $log_name

        backup=/backupit/${realpath}
        inc_rsync
        remove_snap_local

}


# methode Xen LVM
mysql_XENLVM () {

        start_time
        extract_vg

        echo -n "|_ Starting Backup of [guest=>$name on $xenhost] (locking tables + snap) "

        echo "totolog" >>  $log_name
        ssh -n -c blowfish root@$xenhost "a=( \`mount\` ); [[ \${a[*]} =~ backupit ]] && umount -fl /backupit 1>&2
                                          b=( \`lvs\` );[[ \${b[*]} =~ backupit ]] && lvremove -f /dev/$vg/backupit 1>&2" 2>> $log_name

        ssh -f -n -c blowfish root@$hostname "bash -c 'mysql -u$mysql_user -p$mysql_pass -e \"flush tables with read lock;system while [ ! -f /tmp/.backup_lock ]
                                                                               do
                                                                               :
                                                                                 done;unlock tables;system rm /tmp/.backup_lock;\" ';exit" 2>> $log_name


        ssh -n -c blowfish root@$xenhost "lvcreate -s $lvm_part -n backupit -L$lvsize 1>&2" 2>> $log_name
        ssh -n -c blowfish root@$hostname "> /tmp/.backup_lock"
        ssh -n -c blowfish root@$xenhost  "[[ ! -d backupit ]] && mkdir -p /backupit 1>&2 ; mount /dev/$vg/backupit /backupit 1>&2 && echo '[OK]' || echo '[FAILED]'" 2>> $log_name

        backup=/backupit/$realpath
        hostname=$xenhost
        inc_rsync
        remove_snap $xenhost
}






#######################
# PROGRAMME PRINCIPAL #
#######################

if [[ ! $1 ]]; then
        server_list=/etc/backupit/servers/*.conf
else
        if [[ ! $2 ]]; then
                if [[ ! -f "/etc/backupit/servers/${1}.conf" ]]; then
                        echo "ERROR => Can't find => /etc/backupit/servers/${1}.conf"
                        exit
                else
                        server_list="/etc/backupit/servers/${1}.conf"
                fi
        else
                task=1
                if [[ ! -f "/etc/backupit/tasks/${1}.conf" ]]; then
                        echo "ERROR unknow task"
                        exit
                else
                        echo "task detected"
                        server_list="/etc/backupit/tasks/${1}.conf"
                        echo "server => $server_list"
                fi
        fi
fi

echo

putlog HEADER



for server in $server_list; do

        unset name hostname type mysql_user mysql_pass lvsize realpath lvm_part retention backup exclude ip port xenhost bandwidth time_str TSTR2 TSTR tot_size bandwidth bbb FFFAIL

        FFFAIL=0

        echo "[$server]"

        . $server

        echo "realpath => $realpath"

        if [[ $name ]]; then

                [[ ! -d $log_dir/$name ]] && mkdir -p $log_dir/$name 1>/dev/null 2>/dev/null
                log_name=$log_dir/$name/$date_file
                [[ -f $log_name ]] && > $log_name 1>/dev/null 2>/dev/null
                dest=$backup_dir/$name
                [[ ! -d $dest ]] && mkdir -p $dest/backup.0 1>/dev/null 2>/dev/null

                cd $dest

        else

                echo "Fichier de configuration invalide => $server"
                break

        fi

        case $type in

                data_rsync)

                        if [[ ! $hostname || ! $type || ! $retention || ! $backup || ! $exclude || ! $bandwidth || ! $ip || ! $protocol || ! $port ]]; then
                                echo "Il manque un parametre dans le fichier $server" >> $log_name
                                break
                        fi

                        start_time
                        inc_rsync

                ;;


                data_rsync_XEN)

                        if [[ ! $hostname || ! $type || ! $retention || ! $backup || ! $exclude || ! $bandwidth || ! $ip || ! $xenhost || ! $lvm_part || ! $lvsize || ! $protocol ]]; then
                                echo "Il manque un parametre dans le fichier $server" >> $log_name
                                break
                        fi

                        $type

                ;;

                data_rsync_lvm_local)

                        if [[ ! $hostname || ! $type || ! $retention || ! $backup || ! $exclude || ! $bandwidth || ! $ip || ! $xenhost || ! $lvm_part || ! $lvsize || ! $protocol || ! $port ]]; then
                                echo "Il manque un parametre dans le fichier $server" >> $log_name
                                break
                        fi

                        $type

                ;;



                 mysql_LVM)

                        if [[ ! $hostname || ! $type || ! $mysql_user || ! $mysql_pass || ! $lvsize || ! $realpath || ! $lvm_part || ! $retention || ! $backup || ! $exclude || ! $ip || ! $bandwidth || ! $protocol || ! $port ]] ; then
                                echo "Il manque un parametre dans le fichier $server" >> $log_name
                                break
                        fi

                        echo "realpath => $realpath"

                        $type

                ;;


                mysql_XENLVM)

                        if [[ ! $hostname || ! $type || ! $mysql_user || ! $mysql_pass || ! $lvsize || ! $realpath || ! $lvm_part || ! $retention || ! $backup || ! $exclude || ! $ip || ! $bandwidth || ! $xenhost || ! $protocol ]] ; then
                                echo "Il manque un parametre dans le fichier $server" >> $log_name
                                break
                        fi

                        $type

                ;;

                *) echo "Not implemented yet !"  >> $log_name ;;
        esac

        mkdir -p /var/www/rlog/$name &>/dev/null
        cp $log_name /var/www/rlog/$name/.html
        bbb=$(basename $log_name.html)
        putlog '<img src="'${imggogol[$FFFAIL]}'">' "$name" "$type" "$TSTR" "$TSTR2" "$time_str" "+$tot_size Mo" "$bandwidth Mo/s" "<a href='http://backup.net1c.net/rlog/$name/$bbb'>Lire</a>"


        echo
done

((TOTSEC=`date +%s`-start_task,S=TOTSEC,H=S/3600,S=S%3600,M=S/60,S=S%60));((!H||H<=9))&&H=0$H;((!M||M<=9))&&M=0$M;((!S||S<=9))&&S=0$S

bandwidth=$(echo "scale=2;$mega_tot_MB/$TOTSEC"|bc)


echo "Total Backup Time         => $H:$M:$S"
echo "Total Files transfered    => $mega_file_transfered"
echo "Total MB written on disk  => $mega_tot_MB"
echo "Bandwidth Average         => $bandwidth"
echo

putlog FOOTER

echo "To: jeremy@net1c.net
From: backup@net1c.net
Subject: Rapport backup
MIME-Version: 1.0
Content-Type: multipart/alternative;
        boundary=\"----=_Part_16_24402202.1340346601139\"

------=_Part_16_24402202.1340346601139
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: 7bit

------=_Part_16_24402202.1340346601139
Content-Type: multipart/related;
        boundary=\"----=_Part_17_25549967.1340346601139\"

------=_Part_17_25549967.1340346601139
Content-Type: text/html; charset=utf-8
Content-Transfer-Encoding: 7bit

<html>
<body vlink=blue alink=red link=blue>
$mail
</html>

------=_Part_17_25549967.1340346601139
Content-Type: image/jpeg; name=check.jpg
Content-Transfer-Encoding: base64
Content-Disposition: inline; filename=check.jpg
Content-ID: <coabawkodo>

/9j/4AAQSkZJRgABAgAAZABkAAD/7AARRHVja3kAAQAEAAAAZAAA/+4ADkFkb2JlAGTAAAAAAf/b
AIQAAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQICAgICAgICAgIC
AwMDAwMDAwMDAwEBAQEBAQECAQECAgIBAgIDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMD
AwMDAwMDAwMDAwMDAwMDAwMD/8AAEQgAEAAQAwERAAIRAQMRAf/EAHEAAAMAAAAAAAAAAAAAAAAA
AAUGCAEAAgMAAAAAAAAAAAAAAAAAAwYCBQcQAAEFAQEAAwEAAAAAAAAAAAcDBAUGCAIBEhMJFhEA
AgEDAwEGBwAAAAAAAAAAAQIDEQQFITEGEgBBIjJCB1FhcZEjMxb/2gAMAwEAAhEDEQA/AKc/VD9O
9ckDRRUHIHvBNCmfwMVpMGqWceSdloi9mLFZkJSvTyVmIdTeRcr3Py9pgpRvCQCcnwg6i2aLj1ms
6X7+hD5LyR8eXCEpDGaEjvNDufuAAQdCddKYpzfmmWhyEmMw7GG2gYLJIBUlyK9PVSg7wACGqDvs
KkyRorZuEi3kGka+0POF5ntC7w1Fs+cSVY7AQTaAVSTMx9VCpO/sbPJzE4zTstxft2UxXl3njRix
WWUQQ7dtlPgTGZu7tLu0x2bkRb2+RnjhJ/MqrszjcBvgdQdNwwDBgcln8RNZWPJ50ee/BKRH98Q9
Bk+TbEMeoEj1B1APXGXd44R2Ecj7nMLSezMaaWvj02ywP8rEkWFRBpWdevbK8IfYirnC91lJONu6
jmUjZmDZrc9sHCcW/wC23bdq6XhyCy5HY3D5LjkFperJQvbXIBjLrQpIpNellYA1GpFRvQ9i5XH5
7CZebMYO3gvrG5o0tvKocCVaFJUBqVZWAbqTxEVUjynsj4dwVqnVetRdpLQI1MAxpw5L1c0EUifo
KtuxyWDMUh3Jx9nGdIo4vnm7a01WjwVnZMF3SztkyjEIlj7HMPO1O/e0cu9tfbfnKczuvcT3Kuo5
cvIGWCCNusRhtGdmoq+UBY0RQqKPoFqONcXzl9n/AOo5MWF0GLAMfEW7gB6UXQioU6KAo1Pb/9k=
------=_Part_17_25549967.1340346601139
Content-Type: image/jpeg; name=delete.jpg
Content-Transfer-Encoding: base64
Content-Disposition: inline; filename=delete.jpg
Content-ID: <dasjstcroj>

/9j/4AAQSkZJRgABAgAAZABkAAD/7AARRHVja3kAAQAEAAAAZAAA/+4ADkFkb2JlAGTAAAAAAf/b
AIQAAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQICAgICAgICAgIC
AwMDAwMDAwMDAwEBAQEBAQECAQECAgIBAgIDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMD
AwMDAwMDAwMDAwMDAwMDAwMD/8AAEQgAEAAQAwERAAIRAQMRAf/EAG0AAQEBAAAAAAAAAAAAAAAA
AAUGCAEAAgMAAAAAAAAAAAAAAAAABQYDBAcQAAIDAQACAwAAAAAAAAAAAAQFBgcIAwECExQJEQAC
AgICAgAFBQAAAAAAAAABAgMEEQUGByESMUEiExQAUUIjCP/aAAwDAQACEQMRAD8A2RsnYW6P0T3Z
pPHeM9KcsxxbLYVmqIVCUlkPqktPUFnUwYWgslLG5XCSQ5m0c8pOsajhrhGQqxelXejE3j17dvPg
RV2Gwv29i+n1DxJaSIv9RAZyBn0jB+LY8/sB5PjJG+8R4fxHj/DK/Y3Yda7a0Fm6lf8AoRmiqxu4
j/KtsuCkIchBjLM5CLlyqsZkXYG7PzX3Zl7JOz9Peum4jrXtWESm1ayaznFw2zmW07sYDx6sRDpf
MCTpmEd5kxy3gyXFMilRaRh7sQ+XPvy5/Zr6/b3qW4j0G6kha9ND9xQjAshxkxyD5MBhhjwR5HjB
Jfl3XXF+TdcXO3esamyg4prtl+HK1iJkgsoWKJcpyN5eBpFaJ1fDxyAK+GLKoW+8Cb5wbuTT+0MT
Z8VaoqjWqKe9BzAaw8XXdOUbSt9n1lVkSyu66Wmiyju6Lmf326V2AE2X8PRl7ANQuvwj+5MHIdVv
obUm54ulaTZyQNGVm8epYYEsT/wkX4eQVIyCP0T6g551Lt+P1us++rG7qcFrbOK4Jdbh/vJGxZ6N
6ucGxTlJDERskqSKrI4x4ocdYs3v+je28n6/21QfbOsGyHyrF46nEzrMunrv0rY1IljP6zYymGSM
ouaHO+so4gGvHBwipP4BX/RVicOnv7/GL4xx/lFvcx8o5sKabWCqII0rgkv8mnsSHw8rD6VCAIoz
jGcB+7y7f6J4/wBa3Oif8vPySz1/tt621uWNuyotbz7Q6rUVF+qChHITNLJYZ7E0noHLehkf/9k=
------=_Part_17_25549967.1340346601139
Content-Type: image/jpeg; name=error.jpg
Content-Transfer-Encoding: base64
Content-Disposition: inline; filename=error.jpg
Content-ID: <ttayvjebpl>

/9j/4AAQSkZJRgABAgAAZABkAAD/7AARRHVja3kAAQAEAAAAZAAA/+4ADkFkb2JlAGTAAAAAAf/b
AIQAAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQICAgICAgICAgIC
AwMDAwMDAwMDAwEBAQEBAQECAQECAgIBAgIDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMD
AwMDAwMDAwMDAwMDAwMDAwMD/8AAEQgAEAAQAwERAAIRAQMRAf/EAG8AAAMBAAAAAAAAAAAAAAAA
AAQFBggBAAIDAAAAAAAAAAAAAAAAAAQGBQcIEAABBQEBAQADAAAAAAAAAAAEAwUGBwgCCQETFBUR
AAICAAYBBAIDAAAAAAAAAAECAwQRIRIFBgcAQVEiCGETkRQV/9oADAMBAAIRAxEAPwDQ+z/SLR2z
fVZnw/Wl83LmbMsO0o45iIWz9NzKotOfTyGnukXsGUvdisqw8jRQ+2C1GM7O2CFcAfoDclroqFq/
OUk7ct5lffYNkhdoo5JUV3UDVi5yC45fz+Mj5pHhXW1Gr1VuvaO51Y9wtVKNievBIziDTXXFml0E
OQcDkpBGDHUCPFeJfSrSWOPTxbHdn3/b2lMz2HqhPKzWNoOcmWpbMUlkvko0KrOdxqeyAleU9ppz
UwNvfW0gpVq/mkKFDopmJ8/Owtp5Kw5NPxqzIZdDyCNmwDHQcw2GROGeQ9Dl4z9gdIxSdHbT3dst
NaP9irUktwRF2gUWl+DxF8WVQ/xIdifknyJJ8kvSHyN1Xmz04R3pQtW3XofOMt0K3aQPY85KKul8
1bYUilv2dWtHWyMtrU+yHoeTyzpwdWd+b2hxHC5O+Bm8cdpJKkhcu45u025Q73simV0kQyRq4jch
GBxjdgVDYDDA+uB9MPGb6690de7bwvc+sOz5Y6NWxTtR07stWS5WRrMLxmO3XhZJWi1MG1RknTrX
DFtQK86/JjS+kPQmO7Duqn7poGkK80kVqRYvR6B7PeE9nDDOF7GrCF/yZAyRmUvJgUqVBNkkgMZW
xvMTDVSE5/Or85HguD8I32DlNvmHI8Y2d5P0QtIssgEjYtJM6jQX05AL7sT7eWv9pvtF1VufQnHv
rl0sI7sVWtT/ANbc4qktGo7U4gsdTbq07Gwtf9uMjtNhkkKICAWH/9k=
------=_Part_17_25549967.1340346601139
Content-Type: image/jpeg; name=stop.jpg
Content-Transfer-Encoding: base64
Content-Disposition: inline; filename=stop.jpg
Content-ID: <ptuvnlnhdx>

/9j/4AAQSkZJRgABAgAAZABkAAD/7AARRHVja3kAAQAEAAAAZAAA/+4ADkFkb2JlAGTAAAAAAf/b
AIQAAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQICAgICAgICAgIC
AwMDAwMDAwMDAwEBAQEBAQECAQECAgIBAgIDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMD
AwMDAwMDAwMDAwMDAwMDAwMD/8AAEQgAEAAQAwERAAIRAQMRAf/EAG8AAAMBAAAAAAAAAAAAAAAA
AAMFBggBAAIDAAAAAAAAAAAAAAAAAAQGAgMIEAABBQEBAQEBAAAAAAAAAAAHAwQFBggBAgkRFBEA
AgEDBAAFBQEAAAAAAAAAAQIDEQQFIRIGBwBBIhMUUXGBMhYI/9oADAMBAAIRAxEAPwDUWoNG/RX6
t/Rw4Y+xzoR/kGmZJ6ZoqOi4Q2FkMviKqHjFGg8g327XAKRMlapx5M3ZbzyAhlfPmJjodH0sp66/
XU/VO4ustmMy+CwbRRXMMZkdpCwBUFVoNisa1cHUUoPr40Hh8B151z1rb9q9qQX99hMlepZ28Vkk
LyJK0c025/kSwoFCQOp2sWLMDTbr4NkjWH0J+Wm9x5jnaBwe65Hui76JqFJPLAXyeWpsY2otzUTV
aPch5fTDHNbktFou5VFOwVxVP+JRFP08Y9SccV8uQrLM5LFck/lM6ySX0ie4jxklaGlR6gp0qPLX
7irM3JetuF8+6VHf/VEV1ZcWtbo2dzbXaokwkBYLIBC8sZEhViQJCVND+rbIpjX+Pvoj8qfpKaNw
YfEl91QNtnS5Kkp5+Pw/YzYTQ0+KZGQMZKHchQaf3nhKryl2YIvISfVZqJJNkeMV1PDnvtR7LK2O
fxWUOe4uUa8lT25FcVG0lWquoAPpA18vzWngHKuo+e8Dj6m72W5h43j7gXlnPbSGNhOkcsQjlIVn
ZCJ3ainRiSQQQY2uJMM74+o28qRuzew1t+WxpmIgDWxQUBdRNZA4WDneRLJoXKhRDOhXLvHsBQoV
d637O2BNBFvKcS8R8f4UdeH7xiBhePZbJci/s+VbVzCQmGNI9ECbid7CpBcjauhoANNSaNvZncPX
vCemz/mnoITS9b3WRXJXd1dESXD3BhVPjxPtVkto5BLL6l9x3kAY+3Ggf//Z
------=_Part_17_25549967.1340346601139
Content-Type: image/jpeg; name=warn.jpg
Content-Transfer-Encoding: base64
Content-Disposition: inline; filename=warn.jpg
Content-ID: <azqljjnpyv>

/9j/4AAQSkZJRgABAgAAZABkAAD/7AARRHVja3kAAQAEAAAAZAAA/+4ADkFkb2JlAGTAAAAAAf/b
AIQAAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQICAgICAgICAgIC
AwMDAwMDAwMDAwEBAQEBAQECAQECAgIBAgIDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMD
AwMDAwMDAwMDAwMDAwMDAwMD/8AAEQgAEAAQAwERAAIRAQMRAf/EAGkAAAMBAAAAAAAAAAAAAAAA
AAUGCQoBAAIDAQAAAAAAAAAAAAAAAAYHAQMFCBAAAgMAAwEBAQAAAAAAAAAABQYDBAcBAggJABUR
AAICAQUAAwEAAAAAAAAAAAIDAQQFERITBgchIwgA/9oADAMBAAIRAxEAPwDT19ZfZhvAM2tZvmZ1
lEOk6Az7ntLHntgHHoWaeWM3tVYHS+mWzPeamu6hsJ6zErKdy1FHxDH/AGylOxFcB9Ofyn9f9DZ0
PC0Mfh2VB752XKow+GG1BlXnI3NRW6yKtWTVqjEvsccSUwIKjQmjP8UdUwC87dcdwjDEUarbVkhi
JPiSEmQLgiEZayBkQGTH4gi10Gf4x8qfYDBu+YVcv1k2XK6ku5+jbLnbK32xHdu1/wAt7BXsFcne
zXYT0iGk37PZ47KU6yU+1nrybDwlJ5I+p2pHzPj/AKVW9J67blzET2/A5W1h8wpMHC1ZTHslNiVC
yBbFazoNqrLBguBwgX2LZEV9pwqsNk4invnEWlBYrSe3k4HDDFi3bMjDQEoE9PgpiGD9ZhMzJ9L4
D9G2zWfaFvnwK+7lY3JwdVpY1kL6D8X0s/t4evdyargCsJy/cna9cphQOdT83C404FsUpnI2ZI9q
VmGfiCXk/wDQ35W9u9r9wwvpVHs+Fo9O622sWNoTGVS9cgYOsuO1QfVcuzYsCP3VLFdwVkoUqwlk
cwtjovp/T+ndKs9bLHWXZHIg2Lbdtct24WrAFS3eArBZBO1yHDvl+okDpEWnB8t+i4V68Qde/wA7
9Pxc757cc7SjG2EPSniK4kUvPbTeUU70glNGV406DLJhKN5wL5Mig4EVBDTdV4EQq04IqslTvj/n
b8m/oLw/33M+nXO3YS/5/wBldaLKYzZlWuOWG6xVsJtXrFlx3K1hm3nuPsNZVdZW9zmkDxFu592w
HZ8UijWptQ2qsBUUimJ0ARCd/FAL0kB00ShI/C427VAMf//Z
------=_Part_17_25549967.1340346601139
Content-Type: image/jpeg; name=info.jpg
Content-Transfer-Encoding: base64
Content-Disposition: inline; filename=info.jpg
Content-ID: <iahgetuhpe>

/9j/4AAQSkZJRgABAgAAZABkAAD/7AARRHVja3kAAQAEAAAAZAAA/+4ADkFkb2JlAGTAAAAAAf/b
AIQAAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQICAgICAgICAgIC
AwMDAwMDAwMDAwEBAQEBAQECAQECAgIBAgIDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMD
AwMDAwMDAwMDAwMDAwMDAwMD/8AAEQgAEAAQAwERAAIRAQMRAf/EAGoAAAMBAAAAAAAAAAAAAAAA
AAIDBggBAAMBAAAAAAAAAAAAAAAAAAUGBwIQAAEFAQEBAAMBAAAAAAAAAAYDBAUHCAIBCQASExgR
AAIBBAMBAAMBAAAAAAAAAAECAxESBAYhBQcTACIyFP/aAAwDAQACEQMRAD8A0tv36Mat1b9G/wDG
NF3RcWc6WDL5Wz2q/oRyQxVpEBQLkDwZsc4cKBksPmJW5YTUVIpRcI1k0I/qOapOFkvV+luubbrO
mddjazJsfZwx5GSuM04SVxHEFC1RWY1VbxaxdgQA4oBaS0g23dMyHv4dc66R4Q8yRs6R/WSrkAlU
HLW1/kUJIpXn8PBf0J1fkveI/mO7r2tzRVHWZo5tmJdtoV8QSltjxmWlXoXW59BdG8zPHQkr2SLs
0J6AfSLuOQYLqrI8eOf4+/hrbPNcSfRY936qBcZ/88crrG/0iKuKkK4FrUFSrKACF5BuFq5pPqku
RvmRoHazGeVZJVikeP5SViahEkZ5UsKG01KmorxUu23819Y4z+rMT9G8/UYb60oyUup9oBOv6+by
5GbBlkGDiXmLFFZcWGIybLeoSfKJd7KxczHxUg3ZcKptHfH7cc+uMaFuWsdlq+RpG25RwDPjNBHk
mMyoARRS6gj+RRTUqLVFGFTQh6FqGyxd7jblqGPHnZME0ckuK0ohaT5Or/pI36gm0ggg8tdRqWmz
xv8AO3Rmut+w+yLlog6zRWo9pdfWhW2ssfmwsomrEhi3w7rysQIYMI6GNn0NElHLVzLzT+MYsXLR
uoi388ce8c8PnqPrOldf5V13kWgzt2MsGPHFlZpiMUbCIWhIVYluebmqQQeCaAmaeQ+QbwfVu19i
9FiiwDPJOcHr0mGQ8f8AodnkmyJEHzuUNZEi1YcuxWtv5//Z
------=_Part_17_25549967.1340346601139
Content-Type: image/jpeg; name=running.jpg
Content-Transfer-Encoding: base64
Content-Disposition: inline; filename=running.jpg
Content-ID: <octlilkdyc>

/9j/4AAQSkZJRgABAgEBLAEsAAD/4QPQRXhpZgAATU0AKgAAAAgABwESAAMAAAABAAEAAAEaAAUA
AAABAAAAYgEbAAUAAAABAAAAagEoAAMAAAABAAIAAAExAAIAAAAbAAAAcgEyAAIAAAAUAAAAjYdp
AAQAAAABAAAApAAAANAAAAEsAAAAAQAAASwAAAABQWRvYmUgUGhvdG9zaG9wIENTIFdpbmRvd3MA
MjAwNjowNDowNCAxNjo1OToxNgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAEKADAAQAAAAB
AAAAEAAAAAAAAAAGAQMAAwAAAAEABgAAARoABQAAAAEAAAEeARsABQAAAAEAAAEmASgAAwAAAAEA
AgAAAgEABAAAAAEAAAEuAgIABAAAAAEAAAKaAAAAAAAAAEgAAAABAAAASAAAAAH/2P/gABBKRklG
AAECAQBIAEgAAP/tAAxBZG9iZV9DTQAB/+4ADkFkb2JlAGSAAAAAAf/bAIQADAgICAkIDAkJDBEL
CgsRFQ8MDA8VGBMTFRMTGBEMDAwMDAwRDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAENCwsN
Dg0QDg4QFA4ODhQUDg4ODhQRDAwMDAwREQwMDAwMDBEMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwM
DAwM/8AAEQgAEAAQAwEiAAIRAQMRAf/dAAQAAf/EAT8AAAEFAQEBAQEBAAAAAAAAAAMAAQIEBQYH
CAkKCwEAAQUBAQEBAQEAAAAAAAAAAQACAwQFBgcICQoLEAABBAEDAgQCBQcGCAUDDDMBAAIRAwQh
EjEFQVFhEyJxgTIGFJGhsUIjJBVSwWIzNHKC0UMHJZJT8OHxY3M1FqKygyZEk1RkRcKjdDYX0lXi
ZfKzhMPTdePzRieUpIW0lcTU5PSltcXV5fVWZnaGlqa2xtbm9jdHV2d3h5ent8fX5/cRAAICAQIE
BAMEBQYHBwYFNQEAAhEDITESBEFRYXEiEwUygZEUobFCI8FS0fAzJGLhcoKSQ1MVY3M08SUGFqKy
gwcmNcLSRJNUoxdkRVU2dGXi8rOEw9N14/NGlKSFtJXE1OT0pbXF1eX1VmZ2hpamtsbW5vYnN0dX
Z3eHl6e3x//aAAwDAQACEQMRAD8A76v6x02sFlWJkvrdq1wFQBHj772uUz15opde7CyW0sBL7IqI
Ab9N3tvc727UIfVfEaNrMnIY0aNaHMgDw1qRh0Kv0DjHKyHUOBa6smuCHfTaSKd3u3Kvh+9+5L3v
Z9rXg9r3Pc39PHx+n5WSftcI4DPi68XDwv8A/9n/7QimUGhvdG9zaG9wIDMuMAA4QklNBAQAAAAA
AAccAgAAAgACADhCSU0EJQAAAAAAEEYM8okmuFbasJwBobCnkHc4QklNA+0AAAAAABABLAAAAAEA
AQEsAAAAAQABOEJJTQQmAAAAAAAOAAAAAAAAAAAAAD+AAAA4QklNBA0AAAAAAAQAAAB4OEJJTQQZ
AAAAAAAEAAAAHjhCSU0D8wAAAAAACQAAAAAAAAAAAQA4QklNBAoAAAAAAAEAADhCSU0nEAAAAAAA
CgABAAAAAAAAAAI4QklNA/UAAAAAAEgAL2ZmAAEAbGZmAAYAAAAAAAEAL2ZmAAEAoZmaAAYAAAAA
AAEAMgAAAAEAWgAAAAYAAAAAAAEANQAAAAEALQAAAAYAAAAAAAE4QklNA/gAAAAAAHAAAP//////
//////////////////////8D6AAAAAD/////////////////////////////A+gAAAAA////////
/////////////////////wPoAAAAAP////////////////////////////8D6AAAOEJJTQQAAAAA
AAACAAA4QklNBAIAAAAAAAIAADhCSU0ECAAAAAAAEAAAAAEAAAJAAAACQAAAAAA4QklNBB4AAAAA
AAQAAAAAOEJJTQQaAAAAAANTAAAABgAAAAAAAAAAAAAAEAAAABAAAAAPAFMAeQBtAGIAbwBsACAA
UAByAG8AZwByAGUAcwBzAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAQAAAAEAAA
AAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAABAAAAABAAAAAAAAbnVsbAAAAAIAAAAG
Ym91bmRzT2JqYwAAAAEAAAAAAABSY3QxAAAABAAAAABUb3AgbG9uZwAAAAAAAAAATGVmdGxvbmcA
AAAAAAAAAEJ0b21sb25nAAAAEAAAAABSZ2h0bG9uZwAAABAAAAAGc2xpY2VzVmxMcwAAAAFPYmpj
AAAAAQAAAAAABXNsaWNlAAAAEgAAAAdzbGljZUlEbG9uZwAAAAAAAAAHZ3JvdXBJRGxvbmcAAAAA
AAAABm9yaWdpbmVudW0AAAAMRVNsaWNlT3JpZ2luAAAADWF1dG9HZW5lcmF0ZWQAAAAAVHlwZWVu
dW0AAAAKRVNsaWNlVHlwZQAAAABJbWcgAAAABmJvdW5kc09iamMAAAABAAAAAAAAUmN0MQAAAAQA
AAAAVG9wIGxvbmcAAAAAAAAAAExlZnRsb25nAAAAAAAAAABCdG9tbG9uZwAAABAAAAAAUmdodGxv
bmcAAAAQAAAAA3VybFRFWFQAAAABAAAAAAAAbnVsbFRFWFQAAAABAAAAAAAATXNnZVRFWFQAAAAB
AAAAAAAGYWx0VGFnVEVYVAAAAAEAAAAAAA5jZWxsVGV4dElzSFRNTGJvb2wBAAAACGNlbGxUZXh0
VEVYVAAAAAEAAAAAAAlob3J6QWxpZ25lbnVtAAAAD0VTbGljZUhvcnpBbGlnbgAAAAdkZWZhdWx0
AAAACXZlcnRBbGlnbmVudW0AAAAPRVNsaWNlVmVydEFsaWduAAAAB2RlZmF1bHQAAAALYmdDb2xv
clR5cGVlbnVtAAAAEUVTbGljZUJHQ29sb3JUeXBlAAAAAE5vbmUAAAAJdG9wT3V0c2V0bG9uZwAA
AAAAAAAKbGVmdE91dHNldGxvbmcAAAAAAAAADGJvdHRvbU91dHNldGxvbmcAAAAAAAAAC3JpZ2h0
T3V0c2V0bG9uZwAAAAAAOEJJTQQoAAAAAAAMAAAAAT/wAAAAAAAAOEJJTQQUAAAAAAAEAAAARDhC
SU0EDAAAAAACtgAAAAEAAAAQAAAAEAAAADAAAAMAAAACmgAYAAH/2P/gABBKRklGAAECAQBIAEgA
AP/tAAxBZG9iZV9DTQAB/+4ADkFkb2JlAGSAAAAAAf/bAIQADAgICAkIDAkJDBELCgsRFQ8MDA8V
GBMTFRMTGBEMDAwMDAwRDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAENCwsNDg0QDg4QFA4O
DhQUDg4ODhQRDAwMDAwREQwMDAwMDBEMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwM/8AAEQgA
EAAQAwEiAAIRAQMRAf/dAAQAAf/EAT8AAAEFAQEBAQEBAAAAAAAAAAMAAQIEBQYHCAkKCwEAAQUB
AQEBAQEAAAAAAAAAAQACAwQFBgcICQoLEAABBAEDAgQCBQcGCAUDDDMBAAIRAwQhEjEFQVFhEyJx
gTIGFJGhsUIjJBVSwWIzNHKC0UMHJZJT8OHxY3M1FqKygyZEk1RkRcKjdDYX0lXiZfKzhMPTdePz
RieUpIW0lcTU5PSltcXV5fVWZnaGlqa2xtbm9jdHV2d3h5ent8fX5/cRAAICAQIEBAMEBQYHBwYF
NQEAAhEDITESBEFRYXEiEwUygZEUobFCI8FS0fAzJGLhcoKSQ1MVY3M08SUGFqKygwcmNcLSRJNU
oxdkRVU2dGXi8rOEw9N14/NGlKSFtJXE1OT0pbXF1eX1VmZ2hpamtsbW5vYnN0dXZ3eHl6e3x//a
AAwDAQACEQMRAD8A76v6x02sFlWJkvrdq1wFQBHj772uUz15opde7CyW0sBL7IqIAb9N3tvc727U
IfVfEaNrMnIY0aNaHMgDw1qRh0Kv0DjHKyHUOBa6smuCHfTaSKd3u3Kvh+9+5L3vZ9rXg9r3Pc39
PHx+n5WSftcI4DPi68XDwv8A/9k4QklNBCEAAAAAAFMAAAABAQAAAA8AQQBkAG8AYgBlACAAUABo
AG8AdABvAHMAaABvAHAAAAASAEEAZABvAGIAZQAgAFAAaABvAHQAbwBzAGgAbwBwACAAQwBTAAAA
AQA4QklNBAYAAAAAAAcACAAAAAEBAP/hGTRodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvADw/
eHBhY2tldCBiZWdpbj0n77u/JyBpZD0nVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkJz8+Cjx4Onht
cG1ldGEgeG1sbnM6eD0nYWRvYmU6bnM6bWV0YS8nIHg6eG1wdGs9J1hNUCB0b29sa2l0IDMuMC0y
OCwgZnJhbWV3b3JrIDEuNic+CjxyZGY6UkRGIHhtbG5zOnJkZj0naHR0cDovL3d3dy53My5vcmcv
MTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIycgeG1sbnM6aVg9J2h0dHA6Ly9ucy5hZG9iZS5jb20v
aVgvMS4wLyc+CgogPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9J3V1aWQ6ZTA1ZWM0YmEtYzQx
ZC0xMWRhLTg4MWYtYWM4NTJiNmIwNTIwJwogIHhtbG5zOmV4aWY9J2h0dHA6Ly9ucy5hZG9iZS5j
b20vZXhpZi8xLjAvJz4KICA8ZXhpZjpDb2xvclNwYWNlPjE8L2V4aWY6Q29sb3JTcGFjZT4KICA8
ZXhpZjpQaXhlbFhEaW1lbnNpb24+MTY8L2V4aWY6UGl4ZWxYRGltZW5zaW9uPgogIDxleGlmOlBp
eGVsWURpbWVuc2lvbj4xNjwvZXhpZjpQaXhlbFlEaW1lbnNpb24+CiA8L3JkZjpEZXNjcmlwdGlv
bj4KCiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0ndXVpZDplMDVlYzRiYS1jNDFkLTExZGEt
ODgxZi1hYzg1MmI2YjA1MjAnCiAgeG1sbnM6cGRmPSdodHRwOi8vbnMuYWRvYmUuY29tL3BkZi8x
LjMvJz4KIDwvcmRmOkRlc2NyaXB0aW9uPgoKIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSd1
dWlkOmUwNWVjNGJhLWM0MWQtMTFkYS04ODFmLWFjODUyYjZiMDUyMCcKICB4bWxuczpwaG90b3No
b3A9J2h0dHA6Ly9ucy5hZG9iZS5jb20vcGhvdG9zaG9wLzEuMC8nPgogIDxwaG90b3Nob3A6SGlz
dG9yeT48L3Bob3Rvc2hvcDpIaXN0b3J5PgogPC9yZGY6RGVzY3JpcHRpb24+CgogPHJkZjpEZXNj
cmlwdGlvbiByZGY6YWJvdXQ9J3V1aWQ6ZTA1ZWM0YmEtYzQxZC0xMWRhLTg4MWYtYWM4NTJiNmIw
NTIwJwogIHhtbG5zOnRpZmY9J2h0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvJz4KICA8dGlm
ZjpPcmllbnRhdGlvbj4xPC90aWZmOk9yaWVudGF0aW9uPgogIDx0aWZmOlhSZXNvbHV0aW9uPjMw
MC8xPC90aWZmOlhSZXNvbHV0aW9uPgogIDx0aWZmOllSZXNvbHV0aW9uPjMwMC8xPC90aWZmOllS
ZXNvbHV0aW9uPgogIDx0aWZmOlJlc29sdXRpb25Vbml0PjI8L3RpZmY6UmVzb2x1dGlvblVuaXQ+
CiA8L3JkZjpEZXNjcmlwdGlvbj4KCiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0ndXVpZDpl
MDVlYzRiYS1jNDFkLTExZGEtODgxZi1hYzg1MmI2YjA1MjAnCiAgeG1sbnM6eGFwPSdodHRwOi8v
bnMuYWRvYmUuY29tL3hhcC8xLjAvJz4KICA8eGFwOkNyZWF0ZURhdGU+MjAwNi0wNC0wNFQxNjo1
OToxNi0wNTowMDwveGFwOkNyZWF0ZURhdGU+CiAgPHhhcDpNb2RpZnlEYXRlPjIwMDYtMDQtMDRU
MTY6NTk6MTYtMDU6MDA8L3hhcDpNb2RpZnlEYXRlPgogIDx4YXA6TWV0YWRhdGFEYXRlPjIwMDYt
MDQtMDRUMTY6NTk6MTYtMDU6MDA8L3hhcDpNZXRhZGF0YURhdGU+CiAgPHhhcDpDcmVhdG9yVG9v
bD5BZG9iZSBQaG90b3Nob3AgQ1MgV2luZG93czwveGFwOkNyZWF0b3JUb29sPgogPC9yZGY6RGVz
Y3JpcHRpb24+CgogPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9J3V1aWQ6ZTA1ZWM0YmEtYzQx
ZC0xMWRhLTg4MWYtYWM4NTJiNmIwNTIwJwogIHhtbG5zOnN0UmVmPSdodHRwOi8vbnMuYWRvYmUu
Y29tL3hhcC8xLjAvc1R5cGUvUmVzb3VyY2VSZWYjJwogIHhtbG5zOnhhcE1NPSdodHRwOi8vbnMu
YWRvYmUuY29tL3hhcC8xLjAvbW0vJz4KICA8eGFwTU06RGVyaXZlZEZyb20gcmRmOnBhcnNlVHlw
ZT0nUmVzb3VyY2UnPgogICA8c3RSZWY6aW5zdGFuY2VJRD51dWlkOjQwYjA2NjEwLWIwYTItMTFk
YS1hNzFiLWZkOGQyOTY3ZTIxYzwvc3RSZWY6aW5zdGFuY2VJRD4KICAgPHN0UmVmOmRvY3VtZW50
SUQ+YWRvYmU6ZG9jaWQ6cGhvdG9zaG9wOjE2ZDA0ZmRlLWFiMWYtMTFkYS05ZWQyLWE1YjZkMGI1
NmIwNzwvc3RSZWY6ZG9jdW1lbnRJRD4KICA8L3hhcE1NOkRlcml2ZWRGcm9tPgogIDx4YXBNTTpE
b2N1bWVudElEPmFkb2JlOmRvY2lkOnBob3Rvc2hvcDplMDVlYzRiOS1jNDFkLTExZGEtODgxZi1h
Yzg1MmI2YjA1MjA8L3hhcE1NOkRvY3VtZW50SUQ+CiA8L3JkZjpEZXNjcmlwdGlvbj4KCiA8cmRm
OkRlc2NyaXB0aW9uIHJkZjphYm91dD0ndXVpZDplMDVlYzRiYS1jNDFkLTExZGEtODgxZi1hYzg1
MmI2YjA1MjAnCiAgeG1sbnM6ZGM9J2h0dHA6Ly9wdXJsLm9yZy9kYy9lbGVtZW50cy8xLjEvJz4K
ICA8ZGM6Zm9ybWF0PmltYWdlL2pwZWc8L2RjOmZvcm1hdD4KIDwvcmRmOkRlc2NyaXB0aW9uPgoK
PC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAK
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
IAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAog
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgCjw/eHBhY2tldCBlbmQ9J3cnPz7/4gxYSUNDX1BST0ZJTEUAAQEAAAxI
TGlubwIQAABtbnRyUkdCIFhZWiAHzgACAAkABgAxAABhY3NwTVNGVAAAAABJRUMgc1JHQgAAAAAA
AAAAAAAAAAAA9tYAAQAAAADTLUhQICAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAABFjcHJ0AAABUAAAADNkZXNjAAABhAAAAGx3dHB0AAAB8AAAABRia3B0AAAC
BAAAABRyWFlaAAACGAAAABRnWFlaAAACLAAAABRiWFlaAAACQAAAABRkbW5kAAACVAAAAHBkbWRk
AAACxAAAAIh2dWVkAAADTAAAAIZ2aWV3AAAD1AAAACRsdW1pAAAD+AAAABRtZWFzAAAEDAAAACR0
ZWNoAAAEMAAAAAxyVFJDAAAEPAAACAxnVFJDAAAEPAAACAxiVFJDAAAEPAAACAx0ZXh0AAAAAENv
cHlyaWdodCAoYykgMTk5OCBIZXdsZXR0LVBhY2thcmQgQ29tcGFueQAAZGVzYwAAAAAAAAASc1JH
QiBJRUM2MTk2Ni0yLjEAAAAAAAAAAAAAABJzUkdCIElFQzYxOTY2LTIuMQAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWFlaIAAAAAAAAPNRAAEAAAABFsxY
WVogAAAAAAAAAAAAAAAAAAAAAFhZWiAAAAAAAABvogAAOPUAAAOQWFlaIAAAAAAAAGKZAAC3hQAA
GNpYWVogAAAAAAAAJKAAAA+EAAC2z2Rlc2MAAAAAAAAAFklFQyBodHRwOi8vd3d3LmllYy5jaAAA
AAAAAAAAAAAAFklFQyBodHRwOi8vd3d3LmllYy5jaAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAABkZXNjAAAAAAAAAC5JRUMgNjE5NjYtMi4xIERlZmF1bHQgUkdC
IGNvbG91ciBzcGFjZSAtIHNSR0IAAAAAAAAAAAAAAC5JRUMgNjE5NjYtMi4xIERlZmF1bHQgUkdC
IGNvbG91ciBzcGFjZSAtIHNSR0IAAAAAAAAAAAAAAAAAAAAAAAAAAAAAZGVzYwAAAAAAAAAsUmVm
ZXJlbmNlIFZpZXdpbmcgQ29uZGl0aW9uIGluIElFQzYxOTY2LTIuMQAAAAAAAAAAAAAALFJlZmVy
ZW5jZSBWaWV3aW5nIENvbmRpdGlvbiBpbiBJRUM2MTk2Ni0yLjEAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAHZpZXcAAAAAABOk/gAUXy4AEM8UAAPtzAAEEwsAA1yeAAAAAVhZWiAAAAAAAEwJVgBQ
AAAAVx/nbWVhcwAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAo8AAAACc2lnIAAAAABDUlQgY3Vy
dgAAAAAAAAQAAAAABQAKAA8AFAAZAB4AIwAoAC0AMgA3ADsAQABFAEoATwBUAFkAXgBjAGgAbQBy
AHcAfACBAIYAiwCQAJUAmgCfAKQAqQCuALIAtwC8AMEAxgDLANAA1QDbAOAA5QDrAPAA9gD7AQEB
BwENARMBGQEfASUBKwEyATgBPgFFAUwBUgFZAWABZwFuAXUBfAGDAYsBkgGaAaEBqQGxAbkBwQHJ
AdEB2QHhAekB8gH6AgMCDAIUAh0CJgIvAjgCQQJLAlQCXQJnAnECegKEAo4CmAKiAqwCtgLBAssC
1QLgAusC9QMAAwsDFgMhAy0DOANDA08DWgNmA3IDfgOKA5YDogOuA7oDxwPTA+AD7AP5BAYEEwQg
BC0EOwRIBFUEYwRxBH4EjASaBKgEtgTEBNME4QTwBP4FDQUcBSsFOgVJBVgFZwV3BYYFlgWmBbUF
xQXVBeUF9gYGBhYGJwY3BkgGWQZqBnsGjAadBq8GwAbRBuMG9QcHBxkHKwc9B08HYQd0B4YHmQes
B78H0gflB/gICwgfCDIIRghaCG4IggiWCKoIvgjSCOcI+wkQCSUJOglPCWQJeQmPCaQJugnPCeUJ
+woRCicKPQpUCmoKgQqYCq4KxQrcCvMLCwsiCzkLUQtpC4ALmAuwC8gL4Qv5DBIMKgxDDFwMdQyO
DKcMwAzZDPMNDQ0mDUANWg10DY4NqQ3DDd4N+A4TDi4OSQ5kDn8Omw62DtIO7g8JDyUPQQ9eD3oP
lg+zD88P7BAJECYQQxBhEH4QmxC5ENcQ9RETETERTxFtEYwRqhHJEegSBxImEkUSZBKEEqMSwxLj
EwMTIxNDE2MTgxOkE8UT5RQGFCcUSRRqFIsUrRTOFPAVEhU0FVYVeBWbFb0V4BYDFiYWSRZsFo8W
shbWFvoXHRdBF2UXiReuF9IX9xgbGEAYZRiKGK8Y1Rj6GSAZRRlrGZEZtxndGgQaKhpRGncanhrF
GuwbFBs7G2MbihuyG9ocAhwqHFIcexyjHMwc9R0eHUcdcB2ZHcMd7B4WHkAeah6UHr4e6R8THz4f
aR+UH78f6iAVIEEgbCCYIMQg8CEcIUghdSGhIc4h+yInIlUigiKvIt0jCiM4I2YjlCPCI/AkHyRN
JHwkqyTaJQklOCVoJZclxyX3JicmVyaHJrcm6CcYJ0kneierJ9woDSg/KHEooijUKQYpOClrKZ0p
0CoCKjUqaCqbKs8rAis2K2krnSvRLAUsOSxuLKIs1y0MLUEtdi2rLeEuFi5MLoIuty7uLyQvWi+R
L8cv/jA1MGwwpDDbMRIxSjGCMbox8jIqMmMymzLUMw0zRjN/M7gz8TQrNGU0njTYNRM1TTWHNcI1
/TY3NnI2rjbpNyQ3YDecN9c4FDhQOIw4yDkFOUI5fzm8Ofk6Njp0OrI67zstO2s7qjvoPCc8ZTyk
POM9Ij1hPaE94D4gPmA+oD7gPyE/YT+iP+JAI0BkQKZA50EpQWpBrEHuQjBCckK1QvdDOkN9Q8BE
A0RHRIpEzkUSRVVFmkXeRiJGZ0arRvBHNUd7R8BIBUhLSJFI10kdSWNJqUnwSjdKfUrESwxLU0ua
S+JMKkxyTLpNAk1KTZNN3E4lTm5Ot08AT0lPk0/dUCdQcVC7UQZRUFGbUeZSMVJ8UsdTE1NfU6pT
9lRCVI9U21UoVXVVwlYPVlxWqVb3V0RXklfgWC9YfVjLWRpZaVm4WgdaVlqmWvVbRVuVW+VcNVyG
XNZdJ114XcleGl5sXr1fD19hX7NgBWBXYKpg/GFPYaJh9WJJYpxi8GNDY5dj62RAZJRk6WU9ZZJl
52Y9ZpJm6Gc9Z5Nn6Wg/aJZo7GlDaZpp8WpIap9q92tPa6dr/2xXbK9tCG1gbbluEm5rbsRvHm94
b9FwK3CGcOBxOnGVcfByS3KmcwFzXXO4dBR0cHTMdSh1hXXhdj52m3b4d1Z3s3gReG54zHkqeYl5
53pGeqV7BHtje8J8IXyBfOF9QX2hfgF+Yn7CfyN/hH/lgEeAqIEKgWuBzYIwgpKC9INXg7qEHYSA
hOOFR4Wrhg6GcobXhzuHn4gEiGmIzokziZmJ/opkisqLMIuWi/yMY4zKjTGNmI3/jmaOzo82j56Q
BpBukNaRP5GokhGSepLjk02TtpQglIqU9JVflcmWNJaflwqXdZfgmEyYuJkkmZCZ/JpomtWbQpuv
nByciZz3nWSd0p5Anq6fHZ+Ln/qgaaDYoUehtqImopajBqN2o+akVqTHpTilqaYapoum/adup+Co
UqjEqTepqaocqo+rAqt1q+msXKzQrUStuK4trqGvFq+LsACwdbDqsWCx1rJLssKzOLOutCW0nLUT
tYq2AbZ5tvC3aLfguFm40blKucK6O7q1uy67p7whvJu9Fb2Pvgq+hL7/v3q/9cBwwOzBZ8Hjwl/C
28NYw9TEUcTOxUvFyMZGxsPHQce/yD3IvMk6ybnKOMq3yzbLtsw1zLXNNc21zjbOts83z7jQOdC6
0TzRvtI/0sHTRNPG1EnUy9VO1dHWVdbY11zX4Nhk2OjZbNnx2nba+9uA3AXcit0Q3ZbeHN6i3ynf
r+A24L3hROHM4lPi2+Nj4+vkc+T85YTmDeaW5x/nqegy6LzpRunQ6lvq5etw6/vshu0R7ZzuKO60
70DvzPBY8OXxcvH/8ozzGfOn9DT0wvVQ9d72bfb794r4Gfio+Tj5x/pX+uf7d/wH/Jj9Kf26/kv+
3P9t////7gAOQWRvYmUAZEAAAAAB/9sAhAABAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEB
AQEBAQEBAQEBAQEBAgICAgICAgICAgIDAwMDAwMDAwMDAQEBAQEBAQEBAQECAgECAgMDAwMDAwMD
AwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwP/wAARCAAQABADAREAAhEB
AxEB/90ABAAC/8QBogAAAAYCAwEAAAAAAAAAAAAABwgGBQQJAwoCAQALAQAABgMBAQEAAAAAAAAA
AAAGBQQDBwIIAQkACgsQAAIBAwQBAwMCAwMDAgYJdQECAwQRBRIGIQcTIgAIMRRBMiMVCVFCFmEk
MxdScYEYYpElQ6Gx8CY0cgoZwdE1J+FTNoLxkqJEVHNFRjdHYyhVVlcassLS4vJkg3SThGWjs8PT
4yk4ZvN1Kjk6SElKWFlaZ2hpanZ3eHl6hYaHiImKlJWWl5iZmqSlpqeoqaq0tba3uLm6xMXGx8jJ
ytTV1tfY2drk5ebn6Onq9PX29/j5+hEAAgEDAgQEAwUEBAQGBgVtAQIDEQQhEgUxBgAiE0FRBzJh
FHEIQoEjkRVSoWIWMwmxJMHRQ3LwF+GCNCWSUxhjRPGisiY1GVQ2RWQnCnODk0Z0wtLi8lVldVY3
hIWjs8PT4/MpGpSktMTU5PSVpbXF1eX1KEdXZjh2hpamtsbW5vZnd4eXp7fH1+f3SFhoeIiYqLjI
2Oj4OUlZaXmJmam5ydnp+So6SlpqeoqaqrrK2ur6/9oADAMBAAIRAxEAPwDbswf8xTaO6sTQ7i2p
8efkluLbeXh+7wmepMf0bQUmYxzuy02RpqLPd7YfN0tPVxrrRKukpqhVIEkaNdRifzd9+f7pvIXM
++8mc4e81rY80bZcvb3Vu9hu7tDPGdMkbNFt0kbFTglHZa8CehzB7Z8/XVtZ3tty2z2txDHNG31N
kNUcyLJG9GuQw1IytRgGFaMAQQH2b520VHs/L9hZH4wfKDHbC29SZ3Jbj3bJiuja3G4LEbWqa2l3
Plq2lw/e+TzM9FgnxtQZ/tqWolKwt40c6QcjuQOcOUvdHlLYueeQ+Yodw5W3OMvbTiO4h8VQ7Rki
O4hilXvRlGtFrSo7SCQjv+27tyvuVxtO+7XJBfxJG7rqikAWWJJkOqKR1NY5FbBJFaMAwIH/0Ns6
m/lf9S42nhx+D7n+RmBw1HGtNi8JjdzdZtj8TQRDRS46jfI9TV+QkpqSEBEaonnnYLeSR3JY4uc2
fcs+7FzzzPv3OPNPtXDdcybndyXNzMb3c0Ms8zF5H0R3qRrqYk6UVUHBVAoOpg2f37919h2nbNj2
zmWFNts7eOCFWsNukKxRII41LyWjSPpRQNTszGlSSc9CPB8GMBHsas6yqu/fkLkuvsrjM1g81tSs
yPTqUeZwm5Xrm3Hiq7IUHTFFnY4M2uTqFmkp6uCpUTMY5Y20sMguReUeVvbXljZuTeStiiseXNvV
hbwh55BGGkeUgNLK7keI7MAzECukUUACM+Z983rnHeb/AH/mLcmn3S5CiRgkMYYJGsSgJFGiKBGi
r2qOFeNT1//Z
------=_Part_17_25549967.1340346601139
Content-Type: image/jpeg; name=trafficLight.jpg
Content-Transfer-Encoding: base64
Content-Disposition: inline; filename=trafficLight.jpg
Content-ID: <tyogezjkjz>

/9j/4AAQSkZJRgABAgAAZABkAAD/7AARRHVja3kAAQAEAAAAZAAA/+4ADkFkb2JlAGTAAAAAAf/b
AIQAAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQICAgICAgICAgIC
AwMDAwMDAwMDAwEBAQEBAQECAQECAgIBAgIDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMD
AwMDAwMDAwMDAwMDAwMDAwMD/8AAEQgAEAAQAwERAAIRAQMRAf/EAG4AAQEBAAAAAAAAAAAAAAAA
AAgHCgEBAAMAAAAAAAAAAAAAAAAABgIDBBAAAQUBAAIDAQAAAAAAAAAABQIDBAYHAQgJABUKEREA
AgEEAQMDBQEAAAAAAAAAAQIDESEEBQYAEhMxQSJRYTIjFAf/2gAMAwEAAhEDEQA/ANLXuv8AMvZP
DfCcxNZE/NEc0/Qyme3W1BYMafaKxXJlLOS2ZlQbXCMTIdqmF2o8aBMZHzeQpLqHnG+oR35jz5dh
DhyS6rFObsVFUgDiNpTUVVXKsA1KlaihIAJANQo4XquL73lWFp+abkcd4vkylMjZnEfOTCUoxSaT
Eilglli8gRZfHIJERmkVZGQRuYfy+6paNQ9ed0++N3UiIpnk3qdYpobQSZA7bKeElDalbSVeMniy
GyZoku22YlOlSXEMIflzHXG2I6FcZRrFaDuHa1Lj3B9wfuPQ9GpFVJGRHEkauwDgEK4BIDqDcK4A
YA3AIBvXqx+82ibkfpPihf8AB6vq02x5FudjtRS/ZJn5bXzmYBymVW6uSS5DJQga0T7mKsrRJYd1
axcuKMTN7LfU0hv+qE/6RxbUc34LsuKb7WjcafNgVJcPznFaYLIjgR5IBaCVGUSRSrQrIikMp+Qq
febzjKHf8bh/o3eKC8UXeqeQ/iydzq6VKFqB17WPxJUHuB4/KzWLhXPXboLtsDXMVw15T6hNEO3s
ckSflxh9fo1fIsSIKkx5KPpDgeTAUtbDHOrjqSlCeoUhLSJFjhSNQQioqgE1IAUAAt6sQBQsaljU
kmvUu9pP2uKO/wAiLWLXItaxNLW+luv/2Q==
------=_Part_17_25549967.1340346601139--

------=_Part_16_24402202.1340346601139--

" > /tmp/tmpmail


#Envoi du rapport par mail
/usr/sbin/sendmail -t email@domain.com < /tmp/tmpmail-jeremy

