FROM alpine:latest

ENV HOME /root
ENV TOOLS_DIRECTORY /tools
ENV NODEDATA_FOLDER /nodedata
ENV NODEDATA_SEGMENT_FOLDER /nodedata/data
ENV PATH $NODEDATA_FOLDER:$TOOLS_DIRECTORY:$HOME:$PATH

ENV PRIV_KEY_FILE $NODEDATA_FOLDER/privkey.json
ENV REPO_NAME AIOZNetwork/aioz-dcdn-cli-node
ENV BINARY_NAME aioznode

## Tools
RUN mkdir $TOOLS_DIRECTORY
COPY tools/*.* $TOOLS_DIRECTORY/
RUN chmod +x $TOOLS_DIRECTORY/*.sh

## Node data
RUN mkdir $NODEDATA_FOLDER
VOLUME ["$NODEDATA_FOLDER"]

# ports
EXPOSE 1317

## Install deps
RUN apk update
RUN apk add --no-cache $(cat $TOOLS_DIRECTORY/deps.txt)

# Install node
RUN node.install.sh

# Running timeout : Default 24H
ENV RUN_TIMEOUT 86400

# Entry point
CMD start.sh
# CMD bash
