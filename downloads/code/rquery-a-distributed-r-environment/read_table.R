data <- read.table("Sample.txt")

new_data <- lapply(data, function(x) x + 1)

summary(new_data)
