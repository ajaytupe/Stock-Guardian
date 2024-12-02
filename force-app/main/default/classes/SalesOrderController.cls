public without sharing class SalesOrderController {
    @AuraEnabled
    public static String createSalesOrderWithLineItems(Sales_Order__c salesOrder, List<Sales_Order_Line_Item__c> lineItems) {
        String response = 'success';
        try {
            insert salesOrder;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating records: ' + e.getMessage());
        }

        try {
            for (Sales_Order_Line_Item__c item : lineItems) {
                item.Sales_Order__c = salesOrder.Id;
            }
            insert lineItems;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating records: ' + e.getMessage());
        }
 
        new ReplenishmentOrderCreation();
        return response;
    }

    @AuraEnabled(cacheable=true)
    public static List<Inventory_Item__c> getInventoryItems(ID storeID) {
        List<Inventory_Item__c> items = [SELECT Id, Name FROM Inventory_Item__c WHERE Store__c = :storeID];
        return items;
    }
}