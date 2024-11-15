public with sharing class SalesOrderController {
    @AuraEnabled
    public static String createSalesOrderWithLineItems(Sales_Order__c salesOrder, List<Sales_Order_Line_Item__c> lineItems) {
        String answer = '';
        try {
            System.debug('salesOrder =========>' + salesOrder);

            insert salesOrder;
            System.debug('salesOrder.Id =========>' + salesOrder.Id);
        } catch (Exception e) {
            throw new AuraHandledException('Error creating records: ' + e.getMessage());
        }

        
            System.debug('lineItems =========>' + lineItems);
            System.debug('salesOrder.Id =========>' + salesOrder.Id);
            
            // Set the Sales_Order__c ID on each Sales_Order_Line_Item__c record
            for (Sales_Order_Line_Item__c item : lineItems) {
                item.Sales_Order__c = salesOrder.Id;
            }
            System.debug('lineItems 22 =========>' + lineItems);

            insert lineItems;
            answer = 'answer';
        
        return answer;
    }

    @AuraEnabled(cacheable=true)
    public static List<Inventory_Item__c> getInventoryItems(ID storeID) {
        System.debug('storeID =========>' + storeID);
        List<Inventory_Item__c> items = [SELECT Id, Name FROM Inventory_Item__c WHERE Store__c = :storeID];
        System.debug('items =========>' + items);
        return items;
    }
}