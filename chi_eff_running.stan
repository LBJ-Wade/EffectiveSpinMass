functions {
  real linr(real x, real x0, real y0, real x1, real y1) {
    real a = y0/(x0-x1);
    real b = y1/(x1-x0);
    return (x-x1)*a + (x-x0)*b;
  }
}

data {
  int Nobs;
  int Nsamp;
  real chi_eff[Nobs, Nsamp];
  real m1[Nobs, Nsamp];

  int Ndraw;
  int Nsel;
  real chi_eff_sel[Nsel];
  real m1_sel[Nsel];
  real log_sel_wt[Nsel];
}

transformed data {
  real mlow = 10.0;
  real mhigh = 50.0;
}

parameters {
  real<lower=-1,upper=1> mu_10;
  real<lower=0.01, upper=2> sigma_10;
  real<lower=-1,upper=1> mu_50;
  real<lower=0.01, upper=2> sigma_50;
}

transformed parameters {
  real mu0 = linr(30.0, mlow, mu_10, mhigh, mu_50);
  real sigma0 = exp(linr(30.0, mlow, log(sigma_10), mhigh, log(sigma_50)));
  real alpha = (mu_50-mu_10)*30.0/(mhigh-mlow);
  real beta = (log(sigma_50) - log(sigma_10))*30.0/(mhigh-mlow);

  real neff_det;
  real log_mu;

  {
    real log_pdet[Nsel];
    real log_pdet2[Nsel];
    real log_s2;

    for (i in 1:Nsel) {
      real mu = linr(m1_sel[i], mlow, mu_10, mhigh, mu_50);
      real sigma = exp(linr(m1_sel[i], mlow, log(sigma_10), mhigh, log(sigma_50)));

      log_pdet[i] = normal_lpdf(chi_eff_sel[i] | mu, sigma) - log(normal_cdf(1.0, mu, sigma) - normal_cdf(-1.0, mu, sigma));
      log_pdet2[i] = 2.0*log_pdet[i];
    }

    log_mu = log_sum_exp(log_pdet) - log(Ndraw);
    log_s2 = log_diff_exp(log_sum_exp(log_pdet2) - 2.0*log(Ndraw), 2.0*log_mu - log(Ndraw));
    neff_det = exp(2.0*log_mu - log_s2);

    /* Need at least 4*Nobs samples, reject if less than 5*Nobs for safety. */
    if (neff_det < 5*Nobs) reject("too few samples in selection integral");
  }
}

model {
  /* Flat priors on both mu and sigma at both positions */

  for (i in 1:Nobs) {
    real lp[Nsamp];
    for (j in 1:Nsamp) {
      real mu = linr(m1[i,j], mlow, mu_10, mhigh, mu_50);
      real sigma = exp(linr(m1[i,j], mlow, log(sigma_10), mhigh, log(sigma_50)));
      lp[j] = normal_lpdf(chi_eff[i,j] | mu, sigma) - log(normal_cdf(1, mu, sigma) - normal_cdf(-1, mu, sigma));
    }
    target += log_sum_exp(lp) - log(Nsamp);
  }

  target += -Nobs*log_mu + Nobs*(3.0 + Nobs)/(2*neff_det);
}