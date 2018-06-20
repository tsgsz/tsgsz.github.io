data <- load.table("Sample")

new_data <- lapply(data, function(x) x + 1)

kc <- rquery.kmeans(new_data, 3L)

collect(kc$cluster)

kc$centers
