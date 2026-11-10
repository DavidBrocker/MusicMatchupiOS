library(jsonlite)
library(dplyr, quietly = TRUE)

output <- system(
  # "./.build/debug/musickit-sandbox raw /v1/catalog/us/charts --query types=songs",
  "./.build/debug/musickit-sandbox search --term 'Bad Suns' --types artists,albums",
  intern = TRUE
)
json_text <- output[-1] |> paste(collapse = "\n") # drop the leading "HTTP 200" status line

parsed <- fromJSON(json_text, flatten = TRUE)

readr::write_rds(parsed, "file.rds")

songs <- parsed$results$artists$data |>
  as_tibble() |>
  mutate(genres = sapply(attributes.genreNames, paste, collapse = ", ")) |>
  select(
    name = attributes.name,
    genres,
    url = attributes.url
  )

write.csv(songs, "songs.csv")

print(songs)
