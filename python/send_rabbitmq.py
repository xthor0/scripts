#!/usr/bin/env python
import pika
import argparse

# get arguments from command-line
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', required=True, help='RabbitMQ server to connect to', type=str)
parser.add_argument('-m', '--message', required=True, help='Message to push to rabbit queue', type=str)
args = parser.parse_args()

credentials = pika.PlainCredentials('testaccount', 'p@ssw0rd')
parameters = pika.ConnectionParameters(args.server,
                                   5672,
                                   '/',
                                   credentials)

connection = pika.BlockingConnection(parameters)

channel = connection.channel()

channel.queue_declare(queue='hello')

body = "{} : server {}".format(args.message, args.server)

channel.basic_publish(exchange='',
                  routing_key='hello',
                  body=body)
print("Message {} :: Sent".format(body))
connection.close()
