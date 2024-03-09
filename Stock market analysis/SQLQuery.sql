--Creating new column "symbol" for three tables
--Update [dbo].[WIPRO] set [Symbol] = 'Wipro';
--Update [dbo].[TATA CONSULTANCY SERVICES]set [Symbol] = 'TCS';
--Update [dbo].[INFOSYS] set [Symbol] = 'Infosys';

--1)Volatility calculation
drop view if exists A1;
create view A1 as 
( 
Select Symbol, High, low from [dbo].[INFOSYS] where High is NOT NULL or LOW is NOT NULL
Union
Select Symbol,High,Low from [dbo].[TATA CONSULTANCY SERVICES]where High is NOT NULL or LOW is NOT NULL
Union
Select Symbol,High,Low from [dbo].[WIPRO] where High is NOT NULL or LOW is NOT NULL
)
select Symbol,round(avg(high-low),2) as avg_volatility ,dense_rank() over(order by avg(high-low)
asc)as ranking from A1 group by symbol;

--2)drawdown calculation(stock price fall)

   Drop view if Exists A3;
   Create view A3 as 
   (
   Select Max([Close])as Max_C, Min([Close])as Min_C,Symbol from[dbo].[INFOSYS] where [Date] between '2020-02-01' and '2020-03-31'and [Close] is not null group by Symbol
   Union 
   Select Max([Close])as Max_C,Min([Close]) as Min_C,Symbol from [dbo].[TATA CONSULTANCY SERVICES] where [Date] between '2020-02-01' and '2020-03-31'and [Close] is not null group by Symbol
   Union 
   Select Max([Close])as Max_C,Min([Close])as Min_C,Symbol from[dbo].[WIPRO] where [Date] between '2020-02-01' and '2020-03-31'and [Close] is not null group by Symbol
   )
  
 Select Symbol,Max_C,Min_C ,round(((Min_C-Max_C)/Max_C),4)*100 as Drawdown from A3 ;

 --3)Recovery Days Calculation
 
 
Select * into #Recovery_Date from
(
 Select [Date],[Symbol] 
 from
 (
 Select [Date],Symbol,[Close],ROW_NUMBER() over ( order by[Date] asc)as rn 
 from [dbo].[INFOSYS] 
 where [Date] between '2020-03-23' and '2021-03-31' and [Close]>=(Select Max_C from A3 where [Symbol]='Infosys')
 Union
 Select [Date],Symbol,[Close],ROW_NUMBER() over ( order by[Date] asc)as rn 
 from [dbo].[TATA CONSULTANCY SERVICES] 
 where [Date] between '2020-03-19' and '2021-03-31' and [Close]>=(Select Max_C from A3 where [Symbol]='TCS')
 Union
 Select [Date],Symbol,[Close],ROW_NUMBER() over ( order by[Date] asc)as rn 
 from [dbo].[WIPRO] 
 where [Date] between '2020-03-19' and '2021-03-31' and [Close]>=(Select Max_C from A3 where [Symbol]='Wipro')
 )as C 
 where C.rn=1
 ) as R
--adding new date column to our temp table where we store that date where we had our min Closing Amt for march
 alter table #Recovery_Date add Min_Date Date
 Update #Recovery_Date set [Min_Date]='2020-03-23' where Symbol='Infosys'
 Update #Recovery_Date set [Min_Date]='2020-03-19' where Symbol='TCS'
 Update #Recovery_Date set [Min_Date]='2020-03-19' where Symbol='Wipro'

 Select datediff(day,Min_Date,[Date])as Recovery_Days,Symbol from #Recovery_Date 

 --4)Strength (no of days when close prices is higher than prev day stock price) Calculation

 Drop View if exists A2
 create view A2 as(
 Select [Symbol],[Date],[Close],lag([Close])over(order by[Date])as prev_day_close  from [dbo].[INFOSYS] where [Close] is not null
 Union
 Select [Symbol],[Date],[Close],lag([Close])over(order by[Date])as prev_day_close  from [dbo].[TATA CONSULTANCY SERVICES] where [Close] is not null
 Union 
 Select [Symbol],[Date],[Close],lag([Close])over(order by[Date])as prev_day_close  from [dbo].[WIPRO] where [Close] is not null
 )
 
 --Finding Strength using switch case statment

 Select Symbol,sum(
 case 
 when [Close]>[prev_day_close] then 1
 else 0
 end
 )as Strength from A2 group by Symbol

 -----Finding Strength using if statment
 
 Select Symbol,
 sum
 (
 IIF(( [Close]>[prev_day_close]),1,0)
 )as Strength,
 DENSE_RANK() over
(order by 
 sum(IIF(( [Close]>[prev_day_close]),1,0))
)as ranking 
from A2 group by Symbol

--5)CAGR(Compound annual growth Rate) Calculation

--Created a view for end date closing price and start date closing price for each company  
Drop view if exists A4
Create view A4 as
(
(Select [Close],Symbol from A2 where Date= '2002-08-13' )
union
(Select [Close],Symbol from A2 where Date= '2023-06-22' )
)
--self join view A4 to get end price and closing price side by side
Select * 
into #CAGR
from(
Select (round(datediff(day,'2002-08-13','2023-06-22')/365.0,3))as No_of_Years,
t2.[Close]as ending_date_close,
t1.[Close]as starting_date_close,t1.Symbol
from A4 t1,A4 t2 
where t1.Symbol=t2.Symbol and t2.[Close] >[t1].[Close] 
)as td

Select * from #CAGR

Select round((power((ending_date_close/starting_date_close),(1/No_of_Years))-1)*100,3)as CAGR ,Symbol from #CAGR
 
 --6)Maximum Value month

 Select * from
 (Select top 1 Symbol, year([Date])as year,month([Date])as month,
 max([Volume])as Maximum_Volume from INFOSYS
 group by year([Date]),month([date]),Symbol
 order by max(Volume)desc
 Union 
 Select top 1 Symbol, year([Date])as year,month([Date])as month,
 max([Volume])as Maximum_Volume from[dbo].[TATA CONSULTANCY SERVICES]
 group by year([Date]),month([date]),Symbol
 order by max(Volume)desc
 Union
Select top 1 Symbol, year([Date])as year,month([Date])as month,
 max([Volume])as Maximum_Volume from Wipro
 group by year([Date]),month([date]),Symbol
 order by max(Volume)desc)as MVM