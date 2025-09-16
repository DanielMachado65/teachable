# Sinatra MongoDB API Template

This template provides a minimal setup for building an API with [Sinatra](http://sinatrarb.com/) and MongoDB. It includes Docker configuration so the app and database can be run with a single command.

## Features

- Simple Sinatra application structure
- MongoDB connection using the official Ruby driver
- Ready to run with Docker and Docker Compose

## Getting Started

### Running with Docker

1. Build and start the services:
   ```bash
   docker compose up --build
   ```
2. The API will be available at [http://localhost:4567](http://localhost:4567).

### Running locally

1. Install Ruby (3.1 or newer) and Bundler.
2. Install dependencies:
   ```bash
   bundle install
   ```
3. Ensure MongoDB is running and accessible. The default connection string is `mongodb://localhost:27017/mydb`. Override it by setting the `MONGO_URL` environment variable.
4. Start the app:
   ```bash
   bundle exec ruby app.rb
   ```

## Sample Endpoints

- `GET /` - health check endpoint.
- `GET /items` - list items from MongoDB.
- `POST /items` - create a new item. Send JSON in the request body.

## License

This project is released under the [MIT License](LICENSE).
