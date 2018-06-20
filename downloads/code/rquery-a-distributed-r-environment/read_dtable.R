data <- dtable("Sample")

new_data <- lapply(data, function(x) x + 1)

new_data_local <- take(new_data, 1000)

summary(new_data_local)
