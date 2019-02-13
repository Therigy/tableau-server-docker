# tableau-server-docker
Dockerfile for Tableau Server on Linux (Ubuntu 16.04) - Single Node.

This project is a fork of @tfoldi original [repository](https://github.com/tfoldi/tableau-server-docker) for tableau with some major enhancements to get tableau to run correctly as a daemon. Also including a docker-compose file for easily building and running.

## System Dependencies

- Docker >= 17.06
- docker-compose >= 1.14.0

## Build
   
`docker-compose build`
    
## Run

`docker-compose up -d`

It will call a `systemd` `/sbin/init` on the image and configure, register and start tableau server
on the first start.
    
Pro tip: If you commit the image state after the first execution (tableau configuration and registration) you don't
have to wait minutes next time.

## Known Issues

Data persistence with the named volume persists the data associated with original container deployed but if you recreate your compose stack utilizing the same named volume the container crashes.
    
## Author

Authors: [@tfoldi](https://twitter.com/tfoldi)
         [@antoniomercado](https://github.com/antoniomercado)


