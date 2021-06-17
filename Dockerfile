FROM ruby:2.6
 
WORKDIR /app

# Download the release from github
RUN curl -o /usr/local/bin/scw -L "https://github.com/scaleway/scaleway-cli/releases/download/v2.3.1/scw-2.3.1-linux-x86_64"
# Allow executing file as program
RUN chmod +x /usr/local/bin/scw 

COPY main.rb .
COPY docker-entrypoint.sh .

RUN chmod +x main.rb
RUN chmod +x docker-entrypoint.sh 

ENTRYPOINT ["./docker-entrypoint.sh"]
