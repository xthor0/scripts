#!/usr/bin/env python3

from lorem.text import TextLorem
import time
import datetime
from random import randint
import smtplib
from email.mime.text import MIMEText

# some variables do not change
email_sender = 'will@supercoolemail.com'
email_recipients = ['ben@supercoolemail.com', 'aiden@supercoolemail.com', 'will@supercoolemail.com']
body_recipients = ", ".join(email_recipients)
mail_server = "secure.emailsrvr.com"
email_password = "enter the cute password here"

# loop for all of time
while True:
    # new lorem instance for random text
    lorem = TextLorem()

    # a block of random text to go in the email body
    t1 = lorem.text()

    # set the subject to something unique so we don't end up with 
    email_subject = "Hello from {}".format(lorem.sentence())

    email_body = "MIME-Version: 1.0\nContent-type: text/html\nFrom: {efrom}\nTo: {to}\nSubject: {subject}\n\n<b>Hi. This is a randomly-generated message.</b>\n<p>Really, all I'm doing is trying to generate some email for these mailboxes, and keep it continuously flowing.\n<p>This is really just for continuous testing - for before/during/after migration scenarios.\n<p>Here's some random text:\n\n{ipsum}".format(efrom=email_sender, to=body_recipients, subject=email_subject, ipsum=lorem.paragraph())



    try:
        server = smtplib.SMTP(mail_server)
        server.starttls()
        server.login(email_sender, email_password)
        server.ehlo()
        server.sendmail(email_sender, email_recipients, email_body)
        server.close()

        print('Email sent successfully.')
    except:
        print("Error sending email.")

    # generate a random integer
    sleeptime = randint(60,300)

    # convert it to human-readable
    print("Sleeping for {}".format(str(datetime.timedelta(seconds=sleeptime))))

    # sleep
    time.sleep(sleeptime)