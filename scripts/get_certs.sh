for i in $(ssh zolloc.com 'ls -lA /var/www' | awk '{print $NF}'); do
  mkdir /certs/${i}
  mkdir /keys/${i}
  cd /certs/${i}
  wget -O- http://localhost:8080/api/v1/cfssl/newcert --post-data='{"request":{"key":{"algo":"rsa","size":2048},"hosts":["'${i}'","www.'${i}'"],"names":[{"O":"'${i}'"}],"CN":"'${i}'"}}' | /extract_certs.py
done
