--1.List of Persons’ full name, all their fax and phone numbers, as well as the phone number and fax of the company they are working for (if any). 
SELECT FullName, CustomerName AS CompanyName, ap.FaxNumber AS FaxNumbe, ap.PhoneNumber AS PhoneNumber
FROM Application.People ap LEFT JOIN Sales.Customers sc
ON ap.PersonID = sc.PrimaryContactPersonID OR ap.PersonID = sc.AlternateContactPersonID
ORDER BY 1;

--2.If the customer's primary contact person has the same phone number as the customer’s phone number, list the customer companies. 
SELECT CustomerID, CustomerName, sc.PhoneNumber, PrimaryContactPersonID, ap.PhoneNumber
FROM Sales.Customers sc INNER JOIN Application.People ap
ON sc.PrimaryContactPersonID=ap.PersonID
WHERE sc.PhoneNumber=ap.PhoneNumber;

--3.List of customers to whom we made a sale prior to 2016 but no sale since 2016-01-01.
SELECT CustomerID
FROM Sales.Orders
WHERE OrderDate<'2016-01-01' 
AND CustomerID NOT IN (
SELECT Customerid  
FROM Sales.Orders
WHERE OrderDate >='2016-01-01'
GROUP BY CustomerID);

--4.List of Stock Items and total quantity for each stock item in Purchase Orders in Year 2013.
SELECT StockItemID, SUM(OrderedOuters) AS Tot_Quan
FROM Purchasing.PurchaseOrderLines ppol JOIN Purchasing.PurchaseOrders ppo
ON ppol.PurchaseOrderID=ppo.PurchaseOrderID
WHERE Year(OrderDate)=2013
GROUP BY StockItemID
ORDER BY 1 ASC

--5.List of stock items that have at least 10 characters in description.
SELECT DISTINCT ws.StockItemID, StockItemName, Description
FROM Warehouse.StockItems ws JOIN Purchasing.PurchaseOrderLines ppl
ON ws.StockItemID=ppl.StockItemID
WHERE LEN(Description) >= 10
ORDER BY 1 ASC

--6.List of stock items that are not sold to the state of Alabama and Georgia in 2014.
WITH t1 AS (
SELECT StockItemID, wst.CustomerID AS CustomerID, OrderDate
FROM Warehouse.StockItemTransactions wst JOIN Sales.Orders so
ON wst.CustomerID=so.CustomerID),
t2 AS (
SELECT StockItemID, t1.CustomerID AS CustomerID, DeliveryCityID, OrderDate
FROM t1 JOIN Sales.Customers sc
ON t1.CustomerID=sc.CustomerID),
t3 AS (
SELECT StockItemID, CustomerID, CityID, StateProvinceID, OrderDate
FROM t2 JOIN Application.Cities ac
ON DeliveryCityID=CityID)

SELECT DISTINCT StockItemID, t3.StateProvinceID, OrderDate
FROM t3 JOIN Application.StateProvinces a
ON t3.StateProvinceID=a.StateProvinceID
WHERE Year(OrderDate)=2014 AND StateProvinceName!='Alabama' AND StateProvinceName!='Georgia' 
ORDER BY 1

--7.List of States and Avg dates for processing (confirmed delivery date – order date).
WITH t1 AS (
SELECT so.CustomerID AS CustomerID, OrderDate, CAST(ConfirmedDeliveryTime AS date) AS ConfirmedDeliveryDate
FROM Sales.Orders so JOIN Sales.Invoices si
ON so.CustomerID=si.CustomerID),
t2 AS (
SELECT t1.CustomerID AS CustomerID, DeliveryCityID, OrderDate, ConfirmedDeliveryDate, 
DATEDIFF(day, OrderDate, ConfirmedDeliveryDate) AS time_diff
FROM t1 JOIN Sales.Customers sc
ON t1.CustomerID=sc.CustomerID),
t3 AS (
SELECT CustomerID, CityID, StateProvinceID, OrderDate, ConfirmedDeliveryDate, time_diff
FROM t2 JOIN Application.Cities
ON DeliveryCityID=CityID)

SELECT DISTINCT t3.StateProvinceID,
AVG(time_diff) OVER(PARTITION BY StateProvinceName) AS avg_time
FROM t3 JOIN Application.StateProvinces asp
ON t3.StateProvinceID=asp.StateProvinceID

--8.List of States and Avg dates for processing (confirmed delivery date – order date) by month.
SELECT StateProvinceName AS [StateProvinceName], [1] AS JAN, [2] AS FEB, [3] AS MAR, [4] AS APR, [5] AS MAY, 
[6] AS JUN, [7] AS JUL , [8] AS  AUG, [9] AS [SEP], [10] AS OCT, 
[11] AS NOV, [12] AS DEC
FROM (
SELECT asp.StateProvinceName, MONTH(so.OrderDate) AS order_month, DATEDIFF(DAY, so.OrderDate, CAST(si.ConfirmedDeliveryTime as date)) AS processing_diff
FROM Sales.Invoices si JOIN Sales.Orders so ON so.OrderID=si.OrderID
JOIN Sales.Customers sc ON sc.CustomerID=so.CustomerID
JOIN Application.Cities ac ON ac.CityID=sc.DeliveryCityID
JOIN Application.StateProvinces asp ON asp.StateProvinceID=ac.StateProvinceID) t
PIVOT
(AVG(processing_diff)
FOR order_month in ([1], [2], [3], [4], [5], [6], [7], [8],[9],[10],[11],[12])) AS pt

--9.List of StockItems that the company purchased more than sold in the year of 2015.
WITH Item_Purchased AS (
SELECT ppol.StockItemID, ppol.Description,  SUM(ppol.ReceivedOuters) AS Tot_Quan
FROM Purchasing.PurchaseOrderLines ppol
JOIN Purchasing.PurchaseOrders ppo
ON ppol.PurchaseOrderID = ppo.PurchaseOrderID
WHERE YEAR(OrderDate) = 2015
GROUP BY ppol.StockItemID, ppol.Description), 
Item_Sold AS (
SELECT sol.StockItemID, sol.Description, SUM(sol.Quantity) AS Tot_Quan
FROM Sales.OrderLines AS sol
JOIN Sales.Orders AS so
ON sol.OrderID = so.OrderID
WHERE YEAR(OrderDate) = 2015
GROUP BY sol.StockItemID, sol.Description)

SELECT p.StockItemID 
FROM Item_Purchased  p JOIN Item_Sold s
ON p.StockItemID = s.StockItemID 
WHERE p.Tot_Quan > s.Tot_Quan
ORDER BY StockItemID

--10.List of Customers and their phone number, together with the primary contact person’s name, to whom we did not sell more than 10  mugs (search by name) in the year 2016.
SELECT sc.CustomerName, ap.FullName, sc.PhoneNumber
FROM Application.People AS ap JOIN Sales.Customers AS sc
ON ap.PersonID = sc.PrimaryContactPersonID 
WHERE sc.CustomerID NOT IN (
SELECT CustomerID
FROM (
SELECT so.CustomerID, SUM(Quantity) AS Tot_Quan
FROM Sales.OrderLines sol JOIN Sales.Orders so
ON sol.OrderID = so.OrderID 
WHERE sol.Description LIKE '%mug%' AND so.OrderDate BETWEEN '2015-12-31' AND '2017-01-01'
GROUP BY  so.CustomerID
HAVING SUM(Quantity) > 10) t)

--11.List all the cities that were updated after 2015-01-01.
SELECT CityName
FROM Application.Cities
WHERE CAST(ValidFrom AS DATE) > '2015-01-01'

--12.List all the Order Detail (Stock Item name, delivery address, delivery state, city, country, customer name, customer contact person name, customer phone, quantity) for the date of 2014-07-01. Info should be relevant to that date.
SELECT wsi.StockItemName, CONCAT(sc.DeliveryAddressLine1,', ',sc.DeliveryAddressLine2,', ',sc.DeliveryPostalCode) AS DeliverAddress,
asp.StateProvinceName, ac.CityName, Country.CountryName, sc.CustomerName, ap.FullName AS ContactPersonName, sc.PhoneNumber AS CustomerPhone, sol.PickedQuantity
FROM Sales.Orders so JOIN Sales.OrderLines sol
ON so.OrderID = sol.OrderID AND so.OrderDate = '2014-07-01'
JOIN Sales.Customers sc
ON so.CustomerID = sc.CustomerID
JOIN Warehouse.StockItems wsi
ON wsi.StockItemID = sol.StockItemID
JOIN Application.Cities ac
ON ac.CityID = sc.DeliveryCityID
JOIN Application.StateProvinces asp
ON ac.StateProvinceID = asp.StateProvinceID
JOIN Application.Countries Country
ON Country.CountryID = asp.CountryID
JOIN Application.People ap
ON sc.PrimaryContactPersonID = ap.PersonID

--13.List of stock item groups and total quantity purchased, total quantity sold, and the remaining stock quantity (quantity purchased – quantity sold)
SELECT ppol.StockItemID, ppol.Description,
SUM(ppol.OrderedOuters) AS Tot_Quan_B, 
SUM(sol.Quantity)  AS Tot_Quan_S, 
SUM(ppol.OrderedOuters) - SUM(sol.Quantity) AS Remain_Quan
FROM Purchasing.PurchaseOrderLines ppol JOIN Sales.OrderLines sol
ON ppol.StockItemID = sol.StockItemID
GROUP BY ppol.StockItemID, ppol.Description
ORDER BY 1

--14.List of Cities in the US and the stock item that the city got the most deliveries in 2016. If the city did not purchase any stock items in 2016, print “No Sales”.
WITH t1 AS (
SELECT sol.StockItemID, c.DeliveryCityID, COUNT(*) AS Tot
FROM Sales.OrderLines sol JOIN Sales.Orders so ON so.OrderID = sol.OrderID
JOIN sales.Customers c ON so.CustomerID = c.CustomerID
WHERE YEAR(so.OrderDate) = 2016
GROUP BY sol.StockItemID, c.DeliveryCityID),
t2 AS(
SELECT StockItemID, DeliveryCityID
FROM ( 
SELECT StockItemID, DeliveryCityID, DENSE_RANK() OVER(PARTITION BY DeliveryCityId ORDER BY Tot DESC) AS rk
FROM t1) a
WHERE rk = 1)

SELECT ac.CityName, ISNULL(wsi.StockItemName, 'No Sale') AS MostDelivery
FROM t2 JOIN Warehouse.StockItems wsi ON t2.StockItemID = wsi.StockItemID
JOIN Application.Cities ac ON t2.DeliveryCityID = ac.CityID

--15.List any orders that had more than one delivery attempt (located in invoice table).
SELECT InvoiceID, ConfirmedDeliveryTime,
JSON_VALUE(ReturnedDeliveryData, '$.Events[1].Event') AS EventName,
JSON_VALUE(ReturnedDeliveryData, '$.Events[1].EventTime') AS AttemptTime,
JSON_VALUE(ReturnedDeliveryData, '$.Events[1].Status') AS DeliverStatus,
JSON_VALUE(ReturnedDeliveryData, '$.Events[1].ConNote') AS Note,
JSON_VALUE(ReturnedDeliveryData, '$.DeliveredWhen') AS DeliverTime
FROM Sales.Invoices
WHERE JSON_VALUE(ReturnedDeliveryData, '$.Events[1].EventTime') != ConfirmedDeliveryTime

--16.List all stock items that are manufactured in China. (Country of Manufacture)
SELECT StockItemID, StockItemName
FROM Warehouse.StockItems
WHERE JSON_VALUE(CustomFields, '$.CountryOfManufacture') = 'China'

--17.Total quantity of stock items sold in 2015, group by country of manufacturing.
SELECT JSON_VALUE(wsi.CustomFields, '$.CountryOfManufacture') AS CountryofManufacturing, SUM(sol.Quantity) 'Total quantity'
FROM Warehouse.StockItems wsi JOIN Sales.OrderLines sol ON sol.StockItemID =wsi.StockItemID
JOIN Sales.Orders so ON sol.OrderID = so.OrderID 
WHERE YEAR(so.OrderDate) = 2015
GROUP BY JSON_VALUE(wsi.CustomFields, '$.CountryOfManufacture')

--18.Create a view that shows the total quantity of stock items of each stock group sold (in orders) by year 2013-2017. [Stock Group Name, 2013, 2014, 2015, 2016, 2017]
DROP VIEW IF EXISTS StockItem_Sold_Year;
GO
CREATE VIEW StockItem_Sold_Year
AS
SELECT * 
FROM (
SELECT wsg.StockGroupName, sol.Quantity, YEAR(so.OrderDate) AS 'Year'
FROM Sales.Orders so JOIN Sales.OrderLines sol ON so.OrderID = sol.OrderID
JOIN Warehouse.StockItemStockGroups wssg ON sol.StockItemID = wssg.StockItemID
JOIN Warehouse.StockGroups wsg ON wssg.StockGroupID = wsg.StockGroupID
GROUP BY YEAR(so.OrderDate), wsg.StockGroupName, sol.Quantity) tab
PIVOT
(SUM(Quantity)
FOR Year IN([2013], [2014], [2015], [2016], [2017])) pi_t
SELECT * FROM StockItem_Sold_Year
ORDER BY StockGroupName

--19.Create a view that shows the total quantity of stock items of each stock group sold (in orders) by year 2013-2017. [Year, Stock Group Name1, Stock Group Name2, Stock Group Name3, … , Stock Group Name10] 
DROP VIEW IF EXISTS StockItem_Sold_Year;
GO
CREATE VIEW StockItem_Sold_Year 
AS
SELECT * 
FROM(
SELECT wsg.StockGroupName StockGroupName,sol.Quantity, YEAR(so.OrderDate) AS 'year'
FROM Sales.Orders so JOIN Sales.OrderLines sol ON so.OrderID = sol.OrderID
JOIN Warehouse.StockItemStockGroups wssg ON sol.StockItemID = wssg.StockItemID
JOIN Warehouse.StockGroups wsg ON wssg.StockGroupID = wsg.StockGroupID
GROUP BY YEAR(so.OrderDate), wsg.StockGroupName, sol.Quantity) tab
PIVOT
(SUM(Quantity)
FOR StockGroupName in([Novelty Items], [Clothing], [Mugs], [T-Shirts], [Airline Novelties], 
[Computing Novelties], [USB Novelties], [Furry Footwear], [Toys], [Packing Materials])) pi_t
SELECT * FROM StockItem_Sold_Year

--20.Create a function, input: order id; return: total of that order. List invoices and use that function to attach the order total to the other fields of invoices. 
DROP FUNCTION IF EXISTS total_order;
GO
CREATE FUNCTION total_order (@OrderId INT)
RETURNS INT
AS
BEGIN 
	DECLARE @total INT
	SELECT @total = Quantity * UnitPrice + TaxAmount
	FROM Sales.InvoiceLines sil JOIN Sales.Invoices si
	ON sil.InvoiceID=si.InvoiceID AND @OrderId=si.OrderID
END;
GO

--21.Create a new table called ods.Orders. Create a stored procedure, with proper error handling and transactions, that input is a date; when executed, it would find orders of that day, calculate order total, and save the information (order id, order date, order total, customer id) into the new table. If a given date is already existing in the new table, throw an error and roll back. Execute the stored procedure 5 times using different dates. 
DROP PROCEDURE IF EXISTS spGetDate;
GO
CREATE PROCEDURE spGetDate 
@date datetime2(7)
AS
BEGIN 
	SELECT 	OrderID, OrderDate, OrderTotal, CustomerID
	FROM ods.Orders
	WHERE OrderDate=@date
END

DROP TABLE IF exists ods.Orders
CREATE TABLE ods.Orders (
OrderID int, 
OrderDate date,
OrderTotal decimal(18, 2), 
CustomerID int);
INSERT INTO ods.Orders
SELECT 	so.OrderID AS OrderID, OrderDate, Quantity*UnitPrice AS OrderTotal, CustomerID
FROM Sales.Orders so JOIN Sales.OrderLines sol
ON so.OrderID=sol.OrderID


--22
DROP TABLE IF EXISTS ods.StockItem;
GO
CREATE TABLE ods.StockItem (
StockItemID INT, 
StockItemName nvarchar(100), 
SupplierID INT, 
ColorID INT, 
UnitPackageID INT, 
OuterPackageID INT, 
Brand nvarchar(50), 
Size nvarchar(20), 
RecommendedRetailPrice decimal(18, 2), 
TypicalWeightPerUnit decimal(18, 3), 
MarketingComments nvarchar(MAX), 
InternalComments nvarchar(MAX), 
CountryOfManufacture nvarchar(60), 
Range nvarchar(20), 
Shelflife nvarchar(20));
INSERT INTO ods.StockItem
SELECT StockItemID, StockItemName, SupplierID, ColorID, UnitPackageID, OuterPackageID, Brand, Size, 
RecommendedRetailPrice, TypicalWeightPerUnit, MarketingComments, InternalComments,
JSON_VALUE (ws.CustomFields, '$.CountryOfManufacture') AS Country,
JSON_VALUE(ws.CustomFields, '$.Range') AS Range_Type,
JSON_VALUE(ws.CustomFields, '$.ShelfLife') AS ShelfLife
FROM Warehouse.StockItems ws;

--23.Rewrite your stored procedure in (21). Now with a given date, it should wipe out all the order data prior to the input date and load the order data that was placed in the next 7 days following the input date.

--24.
DROP TABLE IF exists Stock_Item;
GO

DECLARE @json nvarchar(MAX) = 
N'{
   "PurchaseOrders":[
      {
         "StockItemName":"Panzer Video Game",
         "Supplier":"7",
         "UnitPackageId":"1",
         "OuterPackageId":[
            6,
            7
         ],
         "Brand":"EA Sports",
         "LeadTimeDays":"5",
         "QuantityPerOuter":"1",
         "TaxRate":"6",
         "UnitPrice":"59.99",
         "RecommendedRetailPrice":"69.99",
         "TypicalWeightPerUnit":"0.5",
         "CountryOfManufacture":"Canada",
         "Range":"Adult",
         "OrderDate":"2018-01-01",
         "DeliveryMethod":"Post",
         "ExpectedDeliveryDate":"2018-02-02",
         "SupplierReference":"WWI2308"
      },
      {
         "StockItemName":"Panzer Video Game",
         "Supplier":"5",
         "UnitPackageId":"1",
         "OuterPackageId":"7",
         "Brand":"EA Sports",
         "LeadTimeDays":"5",
         "QuantityPerOuter":"1",
         "TaxRate":"6",
         "UnitPrice":"59.99",
         "RecommendedRetailPrice":"69.99",
         "TypicalWeightPerUnit":"0.5",
         "CountryOfManufacture":"Canada",
         "Range":"Adult",
         "OrderDate":"2018-01-025",
         "DeliveryMethod":"Post",
         "ExpectedDeliveryDate":"2018-02-02",
         "SupplierReference":"269622390"
      }
   ]
}';

SELECT (
SELECT MAX(StockItemID)+1 
FROM Warehouse.StockItems) StockItemID, 
JSON_VALUE(@json,'$.PurchaseOrders[0].StockItemName') StockItemName,
JSON_VALUE(@json,'$.PurchaseOrders[0].Supplier') SupplierID, NULL ColorID,
JSON_VALUE(@json,'$.PurchaseOrders[0].UnitPackageId') UnitPackageId,
JSON_VALUE(@json,'$.PurchaseOrders[0].OuterPackageId') OuterPackageId,
JSON_VALUE(@json,'$.PurchaseOrders[0].Brand') Brand, NULL Size,
JSON_VALUE(@json,'$.PurchaseOrders[0].LeadTimeDays') LeadTimeDays,
JSON_VALUE(@json,'$.PurchaseOrders[0].QuantityPerOuter') QuantityPerOuter,
CAST(0 AS bit) IsChillerStock, NULL Barcode,
JSON_VALUE(@json,'$.PurchaseOrders[0].TaxRate') TaxRate ,
JSON_VALUE(@json,'$.PurchaseOrders[0].UnitPrice') UnitPrice,
JSON_VALUE(@json,'$.PurchaseOrders[0].RecommendedRetailPrice') RecommendedRetailPrice,
JSON_VALUE(@json,'$.PurchaseOrders[0].TypicalWeightPerUnit') TypicalWeightPerUnit,
NULL MarketingComments, NULL InternalComments, NULL Photo,
JSON_VALUE(@json,'$.PurchaseOrders[0].CountryOfManufacture') CustomFields,
NULL Tags,NULL SearchDetails,1 AS LastEditedBy,
SYSDATETIME() AS ValidFrom, (
SELECT MAX(ValidTo) 
FROM Warehouse.StockItems) AS ValidTo
INTO Stock_Item_New
FROM openjson(@JSON,'$.PurchaseOrders[0]')
WITH (
StockItemID int,
StockItemName nvarchar(100),
SupplierID int,
ColorID int,
UnitPackageID int,
OuterPackageID int,
Brand nvarchar(50),
Size nvarchar(20),
LeadTimeDays int,
QuantityPerOuter int,
IsChillerStock bit,
Barcode nvarchar(50),
TaxRate decimal(18, 3),
UnitPrice decimal(18, 2),
RecommendedRetailPrice decimal(18, 2),
TypicalWeightPerUnit decimal(18, 3),
MarketingComments nvarchar(MAX),
InternalComments nvarchar(MAX),
Photo varbinary(MAX),
CustomFields nvarchar(MAX),
Tags nvarchar(MAX),
SearchDetails nvarchar(MAX),
LastEditedBy int,
ValidFrom datetime2(7),
ValidTo datetime2(7)
)

--25.Revisit your answer in (19). Convert the result in JSON string and save it to the server using TSQL FOR JSON PATH.
DROP VIEW IF EXISTS StockItem_Sold_Year;
GO
CREATE VIEW StockItem_Sold_Year 
AS
SELECT * 
FROM(
SELECT wsg.StockGroupName StockGroupName,sol.Quantity, YEAR(so.OrderDate) AS 'year'
FROM Sales.Orders so JOIN Sales.OrderLines sol ON so.OrderID = sol.OrderID
JOIN Warehouse.StockItemStockGroups wssg ON sol.StockItemID = wssg.StockItemID
JOIN Warehouse.StockGroups wsg ON wssg.StockGroupID = wsg.StockGroupID
GROUP BY YEAR(so.OrderDate), wsg.StockGroupName, sol.Quantity) tab
PIVOT
SELECT  
[Novelty Items] AS Novelty_Items,
[Clothing] AS Clothing, 
[Mugs] AS Mugs,
[T-Shirts] AS TShirts,
[Airline Novelties] AS Airline_Novelties,
[Computing Novelties] AS Computing_Novelties, 
[USB Novelties] AS [USB_Novelties],
[Furry Footwear] AS Furry_Footwear, 
[Toys] AS [Toys], 
[Packing Materials] AS [Packing Materials]
FROM StockItem_Sold_Year
FOR JSON PATH, ROOT('Total_Quantity_Sold')

--26.Revisit your answer in (19). Convert the result into an XML string and save it to the server using TSQL FOR XML PATH.
DROP VIEW IF EXISTS StockItem_Sold_Year;
GO
CREATE VIEW StockItem_Sold_Year 
AS
SELECT * 
FROM(
SELECT wsg.StockGroupName StockGroupName,sol.Quantity, YEAR(so.OrderDate) AS 'year'
FROM Sales.Orders so JOIN Sales.OrderLines sol ON so.OrderID = sol.OrderID
JOIN Warehouse.StockItemStockGroups wssg ON sol.StockItemID = wssg.StockItemID
JOIN Warehouse.StockGroups wsg ON wssg.StockGroupID = wsg.StockGroupID
GROUP BY YEAR(so.OrderDate), wsg.StockGroupName, sol.Quantity) tab
PIVOT
SELECT  
[Novelty Items] AS Novelty_Items,
[Clothing] AS Clothing, 
[Mugs] AS Mugs,
[T-Shirts] AS TShirts,
[Airline Novelties] AS Airline_Novelties,
[Computing Novelties] AS Computing_Novelties, 
[USB Novelties] AS [USB_Novelties],
[Furry Footwear] AS Furry_Footwear, 
[Toys] AS [Toys], 
[Packing Materials] AS [Packing Materials]
FROM StockItem_Sold_Year
FOR XML PATH, ROOT('Total_Quantity_Sold')

--27.Create a new table called ods.ConfirmedDeviveryJson with 3 columns (id, date, value) . Create a stored procedure, input is a date. The logic would load invoice information (all columns) as well as invoice line information (all columns) and forge them into a JSON string and then insert into the new table just created. Then write a query to run the stored procedure for each DATE that customer id 1 got something delivered to him.
