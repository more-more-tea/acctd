#!/bin/bash
# set -x

DBMS=sqlite3
GNUPLOT=gnuplot
DBPATH=~/.acctd.db

CREATTYPTABLE="\
CREATE TABLE categories(category VCHAR(80) PRIMARY KEY);\
"
CREATACCTABLE="\
CREATE TABLE account(item_id INTEGER PRIMARY KEY AUTOINCREMENT,\
                     income REAL, cost REAL, \
                     category VCHAR(80) references categories,\
                     details VCHAR(1024), \
                     year INTEGER, month CHAR(3), day INTEGER);\
"
CREATCATEFRGNKEYTRIGGER="\
CREATE TRIGGER cate_enum_trigger BEFORE INSERT ON account \
FOR EACH ROW
WHEN (SELECT COUNT(*) FROM categories WHERE category = new.category) = 0 \
BEGIN
    SELECT RAISE(ROLLBACK, 'Foreign-key violation: account.category.');
END;\
"

MONTHSTRING=('' 'Jan' 'Feb' 'Mar' 'Apr' 'May' 'Jun' \
             'Jul' 'Aug' 'Sep' 'Oct' 'Nov' 'Dec')

function message {
    echo "1) Oh yeah, I get some (I)ncome!"
    echo "2) Damn, (C)onsumption again."
    echo "3) Come on, it's just a (D)ay!"
    echo "4) What about a (M)onthly statistics?"
    echo "5) A (Y)early one is better."
    echo "6) Hey, please (S)how my cost categories."
    echo "7) Sign, I (R)ecognize another category T_T"
    echo "8) Thank you guy, I wanna (Q)uit my costy life!!!"

    echo -n "There must be one of your choices: "
}

function populate_cost_categories {
    for cate in $*
    do
        `$DBMS $DBPATH "INSERT INTO categories VALUES('$cate');"`
    done
}

function create_db {
    `$DBMS $DBPATH "$CREATTYPTABLE"`
    `$DBMS $DBPATH "$CREATACCTABLE"`
    populate_cost_categories breakfast supper lunch book income miscellanea
    `$DBMS $DBPATH "$CREATCATEFRGNKEYTRIGGER"`
}

function insert_entry {
    income=$1
    cost=$2
    cate=$3
    details=$4
    date=$5
    darr=(`echo $date | sed -n 's/-/ /gp'`)
    year=${darr[0]}
    month=${MONTHSTRING[${darr[1]}]}
    day=${darr[2]}

    `$DBMS $DBPATH \
         "INSERT INTO account \
          ('income', 'cost', 'category', 'details', 'year', 'month', 'day') \
          VALUES \
          ($income, $cost, '$cate', '$details', $year, '$month', $day);"`
}

function daily_stat {
    date=$1
    darr=(`echo $date | sed -n 's/-/ /gp'`)
    year=${darr[0]}
    month=${MONTHSTRING[${darr[1]}]}
    day=${darr[2]}

    echo `$DBMS $DBPATH "SELECT SUM(cost) FROM account \
                         WHERE year=$year AND\
                               month='$month' AND day=$day;"`
}

function monthly_stat {
    date=$1
    darr=(`echo $date | sed -n 's/-/ /gp'`)
    year=${darr[0]}
    month=${MONTHSTRING[${darr[1]}]}

    echo `$DBMS $DBPATH "SELECT day, SUM(cost) FROM account \
                         WHERE year=$year AND month='$month' \
                         GROUP BY day;"`
}

function yearly_stat {
    date=$1
    darr=(`echo $date | sed -n 's/-/ /gp'`)
    year=${darr[0]}

    echo `$DBMS $DBPATH "SELECT month, SUM(cost) FROM account \
                         WHERE year=$year \
                         GROUP BY month;"`
}

function get_date {
    PMT=$1
    FORMAT=$2

    echo -n "$PMT"
    read OPTION
    OPTION=`uppercase $OPTION`
    if [ -z "$OPTION" -o "$OPTION" = "Y" ]
    then
        date=`date +"%Y-%m-%d"`
    else
        echo -n "$FORMAT"
        read date
    fi
}


function uppercase {
    echo $1 | tr '[:lower:]' '[:upper:]'
}

if [ ! -f $DBPATH ]
then
    create_db
fi

while [ 1 ]; do
    echo "What's next?"
    message
    read OPTION
    OPTION=`uppercase $OPTION`
    # fresh parameters
    income=0
    cost=0
    cate=""
    details=""
    date=""

    case $OPTION in
        "I")
            cate="income"
            date=`date +"%Y-%m-%d"`
            echo -n "How much then: "
            read income
            echo
            insert_entry $income $cost "$cate" "$details" $date
            if [ $? -ne 0 ]
            then
                echo "Sorry cannot do that, there must be something wrong."
            else
                echo "￥$income, too far to meet your ends."
            fi
           ;;
        "C")
            get_date "Today's cost? (Y/n): " "YYYY-MM-DD: "
            echo -n "Let look how much you implusively spend: "
            read cost
            echo -n "And where: "
            read cate
            echo -n "Any more you wanna say: "
            read details
            echo
            insert_entry $income $cost "$cate" "$details" $date
            if [ $? -ne 0 ]
            then
                echo "Sorry cannot do that, there must be something wrong."
            else
                echo "￥$cost on $cate. GOOD, I've recorded."
            fi
            ;;
        "D")
            get_date "Still today? (Y/n): " "YYYY-MM-DD: "
            echo
            total=`daily_stat $date`
            echo "How could you spend ￥$total a day!!!"
            ;;
        "M")
            if [ -z "`which $GNUPLOT`" ]
            then
                echo
                echo "Sorry, if you want this, install $GNUPLOT first please :)"
            else
                get_date "This month? (Y/n): " "YYYY-MM: "
                echo
                data=`monthly_stat $date | sed -n 's/|/ /gp'`
                echo $data | gnuplot -p -e \
                    'plot "-" using 1:2 title "monthly statistics" with lines' 2>/dev/null &
            fi
            ;;
        "Y")
            if [ -z "`which $GNUPLOT`" ]
            then
                echo
                echo "Sorry, if you want this, install $GNUPLOT first please :)"
            else
                get_date "This year? (Y/n): " "YYYY: "
                echo
                data=`yearly_stat $date | sed -n 's/|/ /gp'`
                echo $data | gnuplot -p -e \
                    'plot "-" using 2:xticlabels(1) title "monthly statistics" with lines' 2>/dev/null &
            fi
            ;;
        "R")
            echo -n "OK OK, what's it: "
            read category
            echo
            error=`$DBMS $DBPATH "INSERT INTO categories VALUES('$category');"`
            if [ $? -ne 0 ]
            then
                echo "Man, you did something stupid. Maybe the category has already been there."
                echo "Sorry can't do it."
            else
                echo "Here you go."
            fi
            ;;
        "S")
            cates=(`$DBMS $DBPATH "SELECT category FROM categories;"`)
            if [ $? -ne 0 ]
            then
                echo "I cannot figure out, either."
            else
                echo "So many categories:"
                for (( i=0; i < ${#cates[@]}; i++ ))
                do
                    echo -n "$i) "
                    echo ${cates[$i]}
                done
            fi
            ;;
        "Q")
            echo "Bye!"
            break
            ;;
        "*")
            echo "WTF do you want?"
            ;;
    esac

    # delimiter
    echo '----------------------------------------------------------'
done
