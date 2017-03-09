require "sinatra"
require "pg"
require "pry"

set :bind, '0.0.0.0'  # bind to all interfaces

configure :development do
  set :db_config, { dbname: "movies" }
end

configure :test do
  set :db_config, { dbname: "movies_test" }
end

def db_connection
  begin
    connection = PG.connect(Sinatra::Application.db_config)
    yield(connection)
  ensure
    connection.close
  end
end

get '/actors' do
  db_connection do |conn|
    actors = conn.exec("SELECT actors.id, actors.name FROM actors
      ORDER BY actors.name")
    @actors = actors.to_a
  end

  erb :'actors/index'
end

get '/actors/:id' do
  db_connection do |conn|
    movies = conn.exec_params("SELECT movies.title, movies.id, cast_members.character FROM cast_members
      JOIN movies ON cast_members.movie_id = movies.id
      WHERE cast_members.actor_id = ($1)
      ORDER BY movies.title", [params["id"]])

    @movies = movies.to_a
    actor = conn.exec_params("SELECT actors.name FROM actors
    WHERE actors.id = ($1)", [params["id"]])
    @actor = actor.to_a
  end

  erb :'actors/show'
end

year_index = 0
rating_index = 0

get '/movies' do
  if params["page"].nil?
    offset = "0"
    @next_page = 2
  else
    offset = (20 * params["page"].to_i).to_s
    @next_page = params["page"].to_i + 1
    @previous_page = params["page"].to_i - 1
  end
  if params["order"].nil?
    order = "movies.title"
  elsif params["order"] == "year"
    if year_index.even?
      order = "movies.year DESC"
    else
      order = "movies.year"
    end
    year_index +=1
    rating_index = 0
  elsif params["order"] == "rating"
    if rating_index.even?
      order = "CASE WHEN movies.rating is null THEN 1 ELSE 0 END, movies.rating DESC"
    else
      order = "movies.rating"
    end
    rating_index += 1
    year_index = 0
  end
  db_connection do |conn|
    movies = conn.exec("SELECT movies.id, movies.title, movies.year, movies.rating,
      genres.name AS genre, studios.name AS studio FROM movies
      JOIN genres ON movies.genre_id = genres.id
      LEFT JOIN studios ON movies.studio_id = studios.id
      ORDER BY #{order}
      OFFSET #{offset} LIMIT 20")
    @movies = movies.to_a
  end

  erb :'movies/index'
end


get '/movies/:id' do
  db_connection do |conn|
    movie = conn.exec_params("SELECT movies.title, movies.year, movies.rating,
      genres.name AS genre, studios.name AS studio FROM movies
      JOIN genres ON movies.genre_id = genres.id
      LEFT JOIN studios ON movies.studio_id = studios.id
      WHERE movies.id = ($1)", [params["id"]])
    @movie = movie.to_a

    actors = conn.exec_params("SELECT cast_members.character, actors.name, actors.id FROM movies
      JOIN cast_members ON movies.id = cast_members.movie_id
      JOIN actors ON actors.id = cast_members.actor_id
      WHERE movies.id = ($1)", [params["id"]])

    @actors = actors.to_a
  end

  erb :'movies/show'
end
