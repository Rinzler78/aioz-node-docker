# Rolling base on purpose: the container also upgrades its packages and the
# AIOZ CLI at every start (tools/deploy.sh), so a pinned base would not stay pinned.
# hadolint ignore=DL3007 #trivy:ignore:DS-0001
FROM alpine:latest

ENV HOME /root
ENV TOOLS_DIRECTORY /tools
ENV NODEDATA_FOLDER /nodedata
ENV NODEDATA_SEGMENT_FOLDER /nodedata/data
ENV PATH $NODEDATA_FOLDER:$TOOLS_DIRECTORY:$HOME:$PATH

# PRIV_KEY_FILE is the path of the wallet key in the volume, not the key itself.
#trivy:ignore:DS-0031
ENV PRIV_KEY_FILE $NODEDATA_FOLDER/privkey.json
ENV REPO_NAME AIOZNetwork/aioz-depin-cli
ENV BINARY_NAME aioznode

## Tools
COPY tools/*.* $TOOLS_DIRECTORY/

# ports
EXPOSE 1317

## Install deps and the node
# Unpinned packages on purpose: Alpine keeps only the latest version of a package
# in a branch, and tools/deploy.sh runs apk upgrade at every start anyway.
RUN chmod +x $TOOLS_DIRECTORY/*.sh \
    && mkdir -p $NODEDATA_FOLDER \
    && xargs apk add --no-cache < $TOOLS_DIRECTORY/deps.txt \
    && node.install.sh

## Node data
VOLUME ["$NODEDATA_FOLDER"]

# Running timeout : Default 24H
ENV RUN_TIMEOUT 86400

# Withdraw mode (command: start-watching-reward.sh).
# WITHDRAW_ADDRESS_HEX has no default: the withdraw mode refuses to start without it.
ENV CHECK_FREQ=60 \
    WITHDRAW_MIN_VALUE=10^18
# TOKEN_* describe the coin (name, denomination, decimals): they are not secrets.
# hadolint ignore=DL3064 #trivy:ignore:DS-0031
ENV TOKEN_NAME=aioz \
    TOKEN_DENOM=attoaioz \
    TOKEN_DECIMALS=10^18

HEALTHCHECK --interval=1s --timeout=1s --start-period=1s --retries=60 \
    CMD ["aioznode", "reward", "balance"]

# Entry point
CMD ["start.sh"]
