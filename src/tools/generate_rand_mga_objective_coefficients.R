setwd('/random_coefficients')


# connect to the sqlite file
coeff <- data.frame()
r <- 6
c <- 3
iterations <- 3
for (i in 1:iterations){
  A <- as.data.frame(matrix(sample.int(100, 6*3, TRUE), 6, 3))
  m0 <- matrix(0, r, c)
  B <- apply(m0, c(1,2), function(x) sample(c(-1,1),1))
  C <- A * B
  C$Iter <- i
  coeff <- rbind(coeff,C)
}
write.csv(coeff,"rand_mga_objective_coefficients.csv",row.names = FALSE)




