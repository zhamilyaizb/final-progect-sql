create database diploma;
update customer_info set Gender = null where Gender = '';
update customer_info set Age = null where Age = '';
alter table customer_info modify Age int null;
select * from customer_info;

create table transactions
(date_new date,
Id_check int,
ID_client int,
Count_products decimal (10, 3),
Sum_payment decimal (10, 2)
);
load data infile "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\transactions_info.xlsx - TRANSACTIONS (1) 1.csv"
into table transactions
fields terminated by ','
lines terminated by '\n'
ignore 1 rows;

show variables like 'secure_file_priv';
select * from transactions;
select * from customer_info;

#1. Вывести список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе 
#без пропусков за указанный годовой период, средний чек за период с 01.06.2015 по 01.06.2016, 
#средняя сумма покупок за месяц, количество всех операций по клиенту за период.

# использую with cte в рамках одного запроса вместо временной таблицы

with monthly as(
select ID_client, date_format(date_new, '%Y-%m') as month # помесячная разбивка
from transactions
where date_new between "2015-06-01" and "2016-06-01"  
group by ID_client, month
), 
regular_customers as (
select ID_client from monthly # все регулярные клиенты за год
group by ID_client
having count(distinct month) = 12 
),
customer_statistics as (
select ID_client, count(Id_check) as total_operations, 
sum(Sum_payment) as total_expens, 
avg(Sum_payment) as avg_check_year
from transactions 
where date_new between "2015-06-01" and  "2016-06-01"  
group by ID_client
)
select r.ID_client,
cs.total_operations, 
cs.total_expens / 12 as avg_monthly_expens, # cредняя сумма покупок за месяц
cs.avg_check_year  # cредний чек по году
from regular_customers r
join customer_statistics cs on r.ID_client = cs.ID_client
order by avg_monthly_expens desc;


# 2. информацию в разрезе месяцев: a.средняя сумма чека в месяц; b.среднее количество операций в месяц;
# c.среднее количество клиентов, которые совершали операции; d.долю от общего количества операций за год 
# и долю в месяц от общей суммы операций; e.вывести % соотношение M/F/NA в каждом месяце с их долей затрат;

# a.средняя сумма чека в месяц
select date_format(date_new, '%Y-%m')as month, avg(Sum_payment) as avg_check_month
from transactions
group by month
order by month;
 
# b.среднее количество операций в месяц
select date_format(date_new, '%Y-%m') as month, count(Id_check) as avg_operations 
from transactions
group by month
order by month;

# c.среднее количество клиентов, которые совершали операции
select date_format(date_new, '%Y-%m')as month, count(distinct ID_client) as avg_clients 
from transactions
group by month
order by month;

# d.долю от общего количества операций за год и долю в месяц от общей суммы операций
with total_values as (
select count(Id_check) as total_oper, sum(Sum_payment) as total_sum from transactions
)
select date_format(date_new, '%Y-%m')as month, 
count(t.Id_check) / (select total_oper from total_values)*100 as part_percent,
sum(t.Sum_payment) /(select total_sum from total_values) *100 AS sum_part_percent
from transactions t
group by month
order by month;

 # e.вывести % соотношение M/F/NA в каждом месяце с их долей затрат
with gender_data as (
select date_format(date_new, '%Y-%m')as month, 
c.Gender, 
count(t.Id_check) as transaction_count, 
sum(t.Sum_payment) as total_expens
from transactions t
left join customer_info c on t.ID_client = c.Id_client
group by month, c.Gender
)
select 
    g.month, 
    g.Gender, 
    g.transaction_count, 
    g.total_expens,
    g.transaction_count / sum(g.transaction_count) over (partition by g.month)*100 as transaction_percent,
    g.total_expens / sum(g.total_expens) over (partition by g.month)*100 as spending_percent
from gender_data g
order by g.month, g.Gender;

# 3. возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной информации, 
# с параметрами сумма и количество операций за весь период, и поквартально - средние показатели и %.

select * from transactions;
select * from customer_info;

with age_groups as (
select c.ID_client,
case
when c.Age between 0 and 10 then "0-10 лет"
when c.Age between 11 and 20 then "10-20 лет"
when c.Age between 21 and 30 then "20-30 лет"
when c.Age between 31 and 40 then "30-40 лет" 
when c.Age between 41 and 50 then "40-50 лет" 
when c.Age between 51 and 60 then "50-60 лет"
when c.Age between 61 and 70 then "60-70 лет"
when c.Age between 71 and 80 then "70-80 лет"
when c.Age >= 81 then "80+ лет"
when c.Age is null then "Возраст не указан"
end as age_group,
t.Sum_payment,
t.Id_check,
year(t.date_new) as year, 
quarter(t.date_new) as quarter
from transactions t
left join customer_info c
on c.Id_client = t.Id_client
),

total_stats as (
select age_group, count(Id_check) as total_operations,
sum(Sum_payment) as total_spent
from age_groups
group by age_group
),

quarterly_stats as (
select age_group, year, quarter,
count(Id_check) as operations_count,
sum(Sum_payment) as total_spent,
avg(Sum_payment) as avg_check
from age_groups
group by age_group, year, quarter
),

percent as (
select q.age_group, q.year, q.quarter, q.operations_count,
q.total_spent, q.avg_check, q.operations_count / (select sum(operations_count) from quarterly_stats 
where year = q.year and quarter = q.quarter) * 100 as operations_share,
q.total_spent / (select sum(total_spent) from quarterly_stats 
where year = q.year and quarter = q.quarter) * 100 as spent_share
from quarterly_stats q
)

select * from percent
order by year, quarter, age_group;
