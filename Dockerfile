FROM alpine:latest

ENV HOME /root
ENV TOOLS_DIRECTORY /tools
ENV NODEDATA_FOLDER /nodedata
ENV NODEDATA_SEGMENT_FOLDER /nodedata/data
ENV PATH $NODEDATA_FOLDER:$TOOLS_DIRECTORY:$HOME:$PATH

ENV PRIV_KEY_FILE $NODEDATA_FOLDER/privkey.json
ENV REPO_NAME AIOZNetwork/aioz-depin-cli
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

# Withdraw mode (command: start-watching-reward.sh).
# WITHDRAW_ADDRESS_HEX has no default: the withdraw mode refuses to start without it.
ENV CHECK_FREQ 60
ENV WITHDRAW_MIN_VALUE 10^18
ENV TOKEN_NAME aioz
ENV TOKEN_DENOM attoaioz
ENV TOKEN_DECIMALS 10^18

HEALTHCHECK --interval=1s --timeout=1s --start-period=1s --retries=60 \
  CMD aioznode reward balance

# Entry point
CMD start.sh
# CMD bash
