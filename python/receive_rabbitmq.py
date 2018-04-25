#!/usr/bin/env python
import pika
import argparse

# get arguments from command-line
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', required=True, help='RabbitMQ server to connect to', type=str)
args = parser.parse_args()

credentials = pika.PlainCredentials('testaccount', 'p@ssw0rd')
parameters = pika.ConnectionParameters(args.server,
                                   5672,
                                   '/',
                                   credentials)

connection = pika.BlockingConnection(parameters)

channel = connection.channel()


channel.queue_declare(queue='hello')

def callback(ch, method, properties, body):
    print(" [x] Received %r" % body)

channel.basic_consume(callback,
                      queue='hello',
                      no_ack=True)

print(' [*] Waiting for messages. To exit press CTRL+C')
channel.start_consuming()
