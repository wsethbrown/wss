---
id: task-32
title: Address Autocomplete
status: To Do
assignee: []
created_date: '2025-07-16'
labels: []
dependencies: []
---

## Description

Scenario 1: Society Search

As a user, I want to enter my zipcode into the "Enter Zip Code" box and have it correctly display societies that are within the given range of my zip code.

GIVEN we are using a third-party tool like Google Maps

WHEN I enter my Zip Code
AND I define a range in miles
THEN I see Societies that also have zip codes within that range

Scenario 2:
As a user, I want to create an Event for my Society and input my Address. The address will autocomplete, and a Map with a pin on the Address will display in the Event's details page.

GIVEN we are using a third-party tool like Google Maps

WHEN I enter an address in the Event Creation process
THEN the address autocompletes as I type

WHEN I create an Event with a real address
AND I view the Events detail page
THEN I see a map of the address provided by Google Maps
