# Limitations of the GenX Model

While the benefits of an openly available generation and transmission expansion model are high, many approximations have been made due to missing data or to manage computational tractability. The assumptions of the GenX model are listed below. It serves as a caveat to the user and as an encouragement to improve the approximations.

#### 1. Time period
GenX makes the simplifying assumption that each time period contains n copies of a single, representative year. GenX optimizes generation and transmission capacity for just this characteristic year within each time period, assuming the results for different years in the same time period are identical. However, the GenX objective function accounts only for the cost of the final model time period.

#### 2. Cost
The GenX objective function assumes that the cost of powerplants is specified in the unit of currency per unit of capacity. GenX also assumes that the capital cost of technologies is paid through loans.

#### 3.Market
GenX is a bottom-up (technology-explicit), partial equilibrium model that assumes perfect markets for commodities. In other words, each commodity is produced such that the sum of producer and consumer surplus is maximized.

#### 4. Technology
Behavioral response and acceptance of new technology are often modeled simplistically as a discount rate or by externally fixing the technology capacity. A higher, technology-specific discount rate represents consumer reluctance to accept newer technologies.

#### 5. Uncertainty
Because each model realization assumes a particular state of the world based on the input values drawn, the parameter uncertainty is propagated through the model in the case of myopic model runs.

#### 6. Decision-making

GenX assumes rational decision making, with perfect information and perfect foresight, and simultaneously optimizes all decisions over the user-specified time horizon.

#### 7. Demand
GenX assumes price-elastic demand segments that are represented using piece-wise approximation rather than an inverse demand curve to keep the model linear.
