#!/usr/bin/env python

import socket
import argparse

# get arguments from command-line
parser = argparse.ArgumentParser()
parser.add_argument('-P', '--port', required=True, help='TCP port to listen on', type=int)
args = parser.parse_args()

HOST, PORT = '127.0.0.1', args.port

listen_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
listen_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
listen_socket.bind((HOST, PORT))
listen_socket.listen(1)
#print 'Serving HTTP on port %s ...' % PORT
while True:
	client_connection, client_address = listen_socket.accept()
	request = client_connection.recv(1024)
	#print request

	if args.port == 8000:
		http_response = "HTTP/1.1 200 OK\n\nThis is mercury\n"
	elif args.port == 8020:
		http_response = "HTTP/1.1 200 OK\n\nThis is approveme-admin\n"
	elif args.port == 8040:
		http_response = "HTTP/1.1 200 OK\n\nThis is accounts.stormwind.local\n"
	else:
		http_response = "HTTP/1.1 200 OK\n\nSimple web server on TCP port %s\n" % args.port
	
	client_connection.sendall(http_response)
	client_connection.close()

