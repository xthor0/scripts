#!/usr/bin/env python3

import crypt
import getpass
import random
import string
from passlib.hash import sha512_crypt

prompt1 = "Please enter password: "
password1 = getpass.getpass(prompt=prompt1)

prompt2 = "Please enter password again: "
password2 = getpass.getpass(prompt=prompt2)

# compare
if password1 == password2:
    randstring = ''.join(random.sample(string.ascii_letters, 16))
    hash = sha512_crypt.encrypt("test", salt="VFvON1xK")

else:
    print("Sorry, your passwords did not match.")
