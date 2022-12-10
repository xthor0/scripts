#!/usr/bin/env python3

import random
import pprint

participants = ['Autumn', 'Dalton', 'Izzy', 'Aiden']
recipients = []

for giver in participants:
    recipient = "nobody"
    while True:
        recipient = random.choice(participants)
        if recipient not in recipients and recipient != giver:
            break
        
    # print it out
    print("{} gives to {}".format(giver, recipient))
    recipients.append(recipient)