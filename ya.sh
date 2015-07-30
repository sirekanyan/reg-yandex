#!/usr/bin/env bash

mkdir -p tmp

login=`cat /dev/urandom | tr -dc a-z | head -c 8`
password=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 49`

url='https://passport.yandex.ru/registration'
headers="\
-H 'Host: passport.yandex.ru' \
-H 'User-Agent: Mozilla/5.0 (iPhone; U; CPU iPhone OS 3_0 like Mac OS X; en-us)\
 AppleWebKit/528.18 (KHTML, like Gecko) Version/4.0 Mobile/7A341 Safari/528.16' \
-H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
-H 'Accept-Language: en-US,en;q=0.5' \
-H 'Accept-Encoding: gzip, deflate' \
-H 'Connection: keep-alive'"

# download registration page to tmp.html
curl -s -c tmp/cookie.txt "${url}" "${headers}" > tmp/tmp.html

# get yandexuid cookie
yandexuid=`cat tmp/cookie.txt | grep yandexuid | sed 's/.*\t//g'`

# get captcha key
key=`cat tmp/tmp.html | sed -e 's/.*src="https:\/\/\w*\.captcha\.yandex\.net\/image?key=\([^"]*\)".*/\1/'`

# download captcha.gif
cat tmp/tmp.html | sed -e 's/.*src="\(https:\/\/\w*\.captcha\.yandex\.net\/image?key=[^"]*\)".*/\1/' | xargs curl -s -o tmp/captcha.gif

# read captcha
if [ "$DISPLAY" ] ; then
    xdg-open tmp/captcha.gif
else
    echo "Капча сохранена в tmp/captcha.gif"
fi
echo -n 'Введите капчу: '
read captcha

# get registration validation code
track_id=`cat tmp/tmp.html | sed -e 's/.*"\/registration-validations\/transparent\.png?id=\([^"]*\)".*/\1/'`

# send post request
head="${headers} -H 'Referer: ${url} -H 'Cookie: yandexuid=${yandexuid}'"
curl -s "${url}" "${head}" --data "\
track_id=${track_id}\
&language=ru\
&firstname=${login::4}\
&lastname=${login:4:4}\
&login=${login}\
&password=${password}\
&password_confirm=${password}\
&human-confirmation=captcha\
&phone-confirm-state=\
&phone_number=\
&phone_number_confirmed=\
&phone-confirm-password=\
&hint_question_id=3\
&hint_question=\
&hint_answer=${password:0:19}\
&answer=${captcha}\
&key=${key}\
&captcha_mode=text\
&eula_accepted=on" | grep -q 'registration/finish'

if [[ $? -eq 0 ]] ; then
    echo "Логин: ${login}@ya.ru"
    echo "Пароль: ${password}"
    echo "Войти в почту: https://passport.yandex.ru/auth?retpath=https%3A%2F%2Fmail.yandex.ru&login=${login}"
else
    case $(( RANDOM % 5 )) in
        0 )
            echo "Не удалось зарегистрировать почту, попробуйте ещё раз." ;;
        1 )
            echo "Что-то пошло не так. Проверьте фазу луны: https://yandex.ru/search/?text=фаза+луны+сегодня" ;;
        2 )
            echo "Оператор в настоящее время занят, попробуйте завтра в это же время." ;;
        3 )
            echo "Ваш IP-адрес заблокирован Яндексом сроком на 5 лет. Попробуйте позже." ;;
        * )
            echo "Произошла критическая ошибка на сервере Яндекс. За вами уже выехали." ;;
    esac
fi

rm -rf tmp
