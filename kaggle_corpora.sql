-- CeShine Lee's Mean Baseline (LB ~ .59)
-- https://www.kaggle.com/ceshine/mean-baseline-lb-59/

-- dest. table: mean_baseline.num_promotion
SELECT
  item_nbr, store_nbr,
  SUM(CASE WHEN onpromotion = 'True' THEN true ELSE false END) as num_onpromotion,
  14 - SUM(CASE WHEN onpromotion = 'True' THEN true ELSE false END) as num_onnopromotion
FROM
  corpora2.train
WHERE
  id >= 124035459
GROUP BY
  item_nbr, store_nbr

-- dest. table: mean_baseline.train_logsum_2017_aug
SELECT
  item_nbr, store_nbr,
  CASE WHEN onpromotion = 'True' THEN true ELSE false END as onpromotion,
  SUM(CASE WHEN unit_sales < 0 THEN 0 ELSE LN(unit_sales + 1) END) as unit_sales
FROM
  corpora2.train
WHERE
  id >= 124035459
GROUP BY
  item_nbr, store_nbr, onpromotion


-- dest. table: mean_baseline.train_logavg_2017_aug
SELECT
  t.item_nbr as item_nbr,
  t.store_nbr as store_nbr,
  t.onpromotion as onpromotion,
  CASE WHEN t.onpromotion = true THEN
    t.unit_sales / num_onpromotion
  ELSE
    t.unit_sales / num_onnopromotion END as unit_sales
FROM
  mean_baseline.train_logsum_2017_aug as t
LEFT OUTER JOIN
  mean_baseline.num_promotion as p
ON
  t.item_nbr = p.item_nbr AND t.store_nbr = p.store_nbr


-- dest. table: mean_baseline.submit
SELECT
  t.id as id,
  CASE WHEN a.unit_sales is null THEN 0 ELSE EXP(a.unit_sales) - 1 END as unit_sales
FROM
  corpora2.test as t
LEFT OUTER JOIN
  mean_baseline.train_logavg_2017_aug as a
ON
  t.item_nbr = a.item_nbr AND t.store_nbr = a.store_nbr AND
  t.onpromotion = a.onpromotion

-- for debug, you need to import this kernle submit to mean_baseline.submit_kernel
SELECT
  s.id,
  ABS(s.unit_sales - k.unit_sales) as diff
FROM
  mean_baseline.submit as s
LEFT OUTER JOIN
  mean_baseline.submit_kernel as k
ON
  s.id = k.id
ORDER BY
  diff desc
limit 10

-- Paulo Pinto's Log Moving Averages Forecasting (LB=0.546)
-- https://www.kaggle.com/paulorzp/log-moving-averages-forecasting-lb-0-546

-- dest. table: ma8.mst_data
SELECT
  *
FROM
(
SELECT
  distinct(date)
FROM
  corpora2.train
WHERE
  date >= '2017-01-01'
),
(
SELECT
  distinct(store_nbr)
FROM
  corpora2.train
WHERE
  date >= '2017-01-01'
),
(
SELECT
  distinct(item_nbr)
FROM
  corpora2.train
WHERE
  date >= '2017-01-01'
)

-- dest. table: ma8.train_2017_ext
SELECT
  m.date as date,
  m.store_nbr as store_nbr,
  m.item_nbr as item_nbr,
  CASE WHEN t.unit_sales > 0 THEN LN(t.unit_sales + 1) ELSE 0 END unit_sales
FROM
  ma8.mst_data as m
LEFT OUTER JOIN
  corpora2.train as t
ON
  m.date = t.date AND m.store_nbr = t.store_nbr AND m.item_nbr = t.item_nbr
;

-- dest. table: ma8.train_2017_ext_ma_last
SELECT
  *
FROM
(
SELECT
  ROW_NUMBER() OVER(partition by store_nbr, item_nbr order by date desc) row_num,
  date,
  store_nbr,
  item_nbr,
  unit_sales as ma001,
  AVG(unit_sales) OVER(partition by store_nbr, item_nbr order by date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as ma003,
  AVG(unit_sales) OVER(partition by store_nbr, item_nbr order by date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as ma007,
  AVG(unit_sales) OVER(partition by store_nbr, item_nbr order by date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) as ma014,
  AVG(unit_sales) OVER(partition by store_nbr, item_nbr order by date ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) as ma028,
  AVG(unit_sales) OVER(partition by store_nbr, item_nbr order by date ROWS BETWEEN 55 PRECEDING AND CURRENT ROW) as ma056,
  AVG(unit_sales) OVER(partition by store_nbr, item_nbr order by date ROWS BETWEEN 111 PRECEDING AND CURRENT ROW) as ma112,
  AVG(unit_sales) OVER(partition by store_nbr, item_nbr order by date ROWS BETWEEN 223 PRECEDING AND CURRENT ROW) as ma224
FROM
  ma8.train_2017_ext
)
WHERE
  row_num = 1

-- dest. table: ma8.mst_2017_ma8
CREATE TEMPORARY FUNCTION median(x ARRAY<FLOAT64>)
RETURNS FLOAT64
LANGUAGE js AS """
  var center = (x.length / 2) | 0;
  var x_sorted = x.sort();
  if (x_sorted.length % 2) {
    return x_sorted[center];
  } else {
    return (x_sorted[center - 1] + x_sorted[center]) / 2;
  }
""";
SELECT
  store_nbr,
  item_nbr,
  EXP(median([ma001, ma003, ma007, ma014, ma028, ma056, ma112, ma224])) - 1 as unit_sales
FROM
  `ma8.train_2017_ext_ma_last`


-- dest. table: mean_baseline.submit_ma8
SELECT
  t.id as id,
  CASE WHEN a.unit_sales is null THEN 0 ELSE a.unit_sales END as unit_sales
FROM
  corpora2.test as t
LEFT OUTER JOIN
  ma8.mst_2017_ma8 as a
ON
  t.item_nbr = a.item_nbr AND t.store_nbr = a.store_nbr

-- for debug, you need to import this kernle submit to mean_baseline.submit_kernel
SELECT
  s.id,
  ABS(s.unit_sales - k.unit_sales) as diff
FROM
  ma8.submit_ma8 as s
LEFT OUTER JOIN
  ma8.submit_kernel as k
ON
  s.id = k.id
ORDER BY
  diff desc
limit 10
