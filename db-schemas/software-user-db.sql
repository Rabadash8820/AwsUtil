-- MySQL dump 10.13  Distrib 5.6.23, for Win64 (x86_64)
--
-- Host: localhost    Database: software-user-db
-- ------------------------------------------------------
-- Server version	5.6.25-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `payment-methods`
--

DROP TABLE IF EXISTS `payment-methods`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `payment-methods` (
  `ID` char(36) NOT NULL,
  `UserID` char(36) NOT NULL,
  `Identifier` varchar(45) NOT NULL,
  `NameOnCard` varchar(45) NOT NULL,
  `CardNumberHash` binary(32) NOT NULL COMMENT 'SHA2 hash of the card number',
  `ExpirationDate` date NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `payment-method` (`UserID`,`Identifier`),
  KEY `payment-method-user` (`UserID`),
  CONSTRAINT `payment-method-user` FOREIGN KEY (`UserID`) REFERENCES `users` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `products`
--

DROP TABLE IF EXISTS `products`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `products` (
  `ID` char(36) NOT NULL,
  `Name` varchar(45) NOT NULL,
  `CurrentVersion` varchar(25) DEFAULT NULL COMMENT 'Current version, using semantic versioning (e.g., 1.3.1)',
  `DownloadURL` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `Name_UNIQUE` (`Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `user-product-assoc`
--

DROP TABLE IF EXISTS `user-product-assoc`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user-product-assoc` (
  `UserID` char(36) NOT NULL,
  `ProductID` char(36) NOT NULL,
  `DateAcquired` date DEFAULT NULL COMMENT 'The date, in yyyy-mm-dd format, when this user acquired this product (e.g. by purchasing or registering)',
  PRIMARY KEY (`UserID`),
  KEY `user-product-assoc-date-acquired` (`DateAcquired`),
  KEY `user-product-assoc-product_idx` (`ProductID`),
  CONSTRAINT `user-product-assoc-product` FOREIGN KEY (`ProductID`) REFERENCES `products` (`ID`) ON UPDATE CASCADE,
  CONSTRAINT `user-product-assoc-user` FOREIGN KEY (`UserID`) REFERENCES `users` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `users` (
  `ID` char(36) NOT NULL,
  `Email` varchar(45) NOT NULL,
  `PasswordHash` binary(32) NOT NULL COMMENT 'SHA2 hash of the user''s password',
  `EmailConfirmed` bit(1) NOT NULL,
  `FirstName` varchar(45) DEFAULT NULL,
  `LastName` varchar(45) DEFAULT NULL,
  `Birthday` date DEFAULT NULL COMMENT 'The user''s birthday, in yyyy-mm-dd format, for age restriction purposes.',
  `ProfilePicture` blob,
  `ReceiveEmails` bit(1) NOT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `user-email` (`Email`),
  KEY `user-birthday` (`Birthday`),
  KEY `user-email-confirmed` (`EmailConfirmed`),
  KEY `user-receive-emails` (`ReceiveEmails`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2016-11-14  1:35:14
