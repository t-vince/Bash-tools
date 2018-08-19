# General
Scripting languages are pretty awesome to automate things. For example, creating daily or weekly backups.
However, when creating a backup of sensitive data, you wish to encrypt it somehow before storing it so even if it somehow gets in the wrong hands, it remains safe.

There are many ways to encrypt and usually you need a key/password/passphrase. But if you give the key to your script, your script needs access to the key in raw format, which means if someone enters your server and can get a hold of the backups, they can also look into the script and just read the password.
A solution, that we used here, is RSA encryption. RSA is widely used and required a public key to encrypt and a private key to decrypt. Which means you can keep the private key secret off the server.

The problem with RSA is that it is not made to encrypt large files as it uses asymmetric encryption. This basically means that the key needs to be as long as the file you wish to encrypt.

A possible solution to encrypt large files and still use RSA is by using a hybrid solution. 
For example, we could encrypt a large file using the asymmetric algorithm AES and a randomly generated secret. This secret we can encrypt using our RSA key as it is a shorter file.

To decrypt the large file, we then need our RSA secret to decrypt the encryption key for the large file which we can use to decrypt the large file.

Because the encryption key is always randomly generated, it should be safe to assume no one can guess this key and thus the file is securely encrypted.

## Ready-to-use one-liner to decrypt/encrypt
You can run the script like ./encrypt -k <nameOfKeyfile> -i <nameOfEncryptedDBFile> [-d ]

(The "-d" parameter denotes whether its encryption or decryption)

E.g.:
```shell
bash encrypt.sh -k private_RSA_key -i shared--2017-05-10_16-23.sql.gz.tar.gz -d
```

## Script explained
### Keypair
Create a public and private keypair (only needed once)

```shell
ssh-keygen -b 4096 -t rsa -f <NameOfOutputFile>
openssl rsa -in <NameOfOutputFile> -pubout > <NameOfPublicKey>.pem
```

Store the private key somewhere safe, e.g. a password manager
You can later generate the public key from the private key, but not the other way around.

### Encryption
Generate a random key
Encrypt this random key using our public key from our keypair
Also use the random key to encrypt the large file using AES
Remove unencrypted random key
Gzip file and encrypted key

```shell
openssl rand -base64 32 > randomkey.txt
openssl rsautl -encrypt -inkey <NameOfPublicKey>.pem -pubin -in randomkey.txt -out randomkey.txt.enc
openssl enc -aes-256-cbc -salt -in <LargeFileThatNeedsEncrytion> -out  <LargeFileThatNeedsEncrytion>.enc -pass file:./randomkey.txt
tar cvzf backupfilename.tar.gz <LargeFileThatNeedsEncrytion>.enc randomkey.txt.enc
rm randomkey.txt*
rm <LargeFileThatNeedsEncrytion>*
```

### Decryption
Unpack & Decrypt the key and file using the secret from step A (Keypair step)

```shell
tar xvzf backupfilename.tar.gz -C unpacked/
openssl rsautl -decrypt -inkey id_rsa.pem -in unpacked/randomkey.txt.enc -out unpacked/randomkey.txt 
openssl enc -d -aes-256-cbc -in unpacked/<LargeFileThatNeedsEncrytion>.enc -out <LargeFileThatNeedsEncrytion> -pass file:.unpacked/randomkey.txt
rm -rf unpacked
```

### More info
http://www.czeskis.com/random/openssl-encrypt-file.html
https://docs.oracle.com/en/cloud/paas/database-dbaas-cloud/csdbi/generate-ssh-key-pair.html#GUID-4285B8CF-A228-4B89-9552-FE6446B5A673
