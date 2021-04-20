FROM node:current

RUN npm install --global prettier

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]