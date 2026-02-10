data <- read.table("Sample.txt")

new_data <- lapply(data, function(x) x + 1)

kc <- kmeans(new_data, 3L)

kc$cluster

kc$centers
