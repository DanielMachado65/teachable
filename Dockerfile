FROM ruby:3.2.9-alpine3.21

RUN apk add --no-cache build-base
ENV RACK_ENV=development

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 4567