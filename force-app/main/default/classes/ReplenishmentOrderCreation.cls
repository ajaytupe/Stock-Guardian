public without sharing class ReplenishmentOrderCreation implements Schedulable {
    
    // Constructor to start the replenishment process
    @AuraEnabled
    public static void triggerReplenishmentProcess() {
        new ReplenishmentOrderCreation();
    }

    public ReplenishmentOrderCreation() {
        // Fetch inventory items needing replenishment
        List<Inventory_Item__c> inventoryItems = getInventoryItems();

        // Group inventory items by supplier
        Map<Id, List<Inventory_Item__c>> supplierWiseItems = groupItemsBySupplier(inventoryItems);

        // Create replenishment orders
        List<Replenishment_Order__c> replenishmentOrders = createReplenishmentOrders(supplierWiseItems);

        // Insert replenishment orders and get the mapping of supplier to order IDs
        Map<Id, Id> supplierToOrderMap = insertReplenishmentOrders(replenishmentOrders);

        // Create replenishment order line items
        List<Replenishment_Order_Line_Item__c> lineItems = createLineItems(supplierWiseItems, supplierToOrderMap);

        // Insert replenishment order line items
        //insertLineItems(lineItems);

        //sendEmailsForReplenishmentOrders(replenishmentOrders);
    }

    // Fetch inventory items needing replenishment
    private List<Inventory_Item__c> getInventoryItems() {
        return [SELECT ID, Supplier__c, Stock_Level__c, Reorder_Threshold__c, Shortage__c, One_Pack_Quantity__c
                FROM Inventory_Item__c
                WHERE Shortage__c > 0 AND Shortage__c != null
                ORDER BY LastModifiedDate DESC
                LIMIT 1];
    }

    // Group inventory items by Supplier ID
    private Map<Id, List<Inventory_Item__c>> groupItemsBySupplier(List<Inventory_Item__c> inventoryItems) {
        Map<Id, List<Inventory_Item__c>> supplierWiseItems = new Map<Id, List<Inventory_Item__c>>();
        for (Inventory_Item__c item : inventoryItems) {
            if (!supplierWiseItems.containsKey(item.Supplier__c)) {
                supplierWiseItems.put(item.Supplier__c, new List<Inventory_Item__c>());
            }
            supplierWiseItems.get(item.Supplier__c).add(item);
        }
        return supplierWiseItems;
    }

    // Create replenishment orders for each supplier
    private List<Replenishment_Order__c> createReplenishmentOrders(Map<Id, List<Inventory_Item__c>> supplierWiseItems) {
        List<Replenishment_Order__c> replenishmentOrders = new List<Replenishment_Order__c>();
        for (Id supplierId : supplierWiseItems.keySet()) {
            Replenishment_Order__c repOrder = new Replenishment_Order__c();
            repOrder.Supplier__c = supplierId;
            repOrder.Order_Date__c = Date.today();
            replenishmentOrders.add(repOrder);
        }
        return replenishmentOrders;
    }

    // Insert replenishment orders and map Supplier IDs to Replenishment Order IDs
    private Map<Id, Id> insertReplenishmentOrders(List<Replenishment_Order__c> replenishmentOrders) {
        insert replenishmentOrders;
        Map<Id, Id> supplierToOrderMap = new Map<Id, Id>();
        for (Replenishment_Order__c repOrder : replenishmentOrders) {
            supplierToOrderMap.put(repOrder.Supplier__c, repOrder.Id);
        }
        return supplierToOrderMap;
    }

    // Create replenishment order line items
    private List<Replenishment_Order_Line_Item__c> createLineItems(Map<Id, List<Inventory_Item__c>> supplierWiseItems, 
                                                                  Map<Id, Id> supplierToOrderMap) {
        List<Replenishment_Order_Line_Item__c> lineItems = new List<Replenishment_Order_Line_Item__c>();
        for (Id supplierId : supplierWiseItems.keySet()) {
            Id orderId = supplierToOrderMap.get(supplierId);
            for (Inventory_Item__c item : supplierWiseItems.get(supplierId)) {
                Replenishment_Order_Line_Item__c lineItem = new Replenishment_Order_Line_Item__c();
                lineItem.Replenishment_Order__c = orderId;
                lineItem.Inventory_Item__c = item.Id;

                Integer multiplier = (Integer) Math.ceil((Decimal) item.Shortage__c / item.One_Pack_Quantity__c);
                lineItem.Quantity__c = item.One_Pack_Quantity__c * multiplier;

                lineItems.add(lineItem);
            }
        }
        insert lineItems;
        return lineItems;
    }

    // Insert replenishment order line items
    private void insertLineItems(List<Replenishment_Order_Line_Item__c> lineItems) {
        insert lineItems;
    }

    // Schedulable method
    public void execute(SchedulableContext sc) {
        // Call the constructor to trigger the process
        new ReplenishmentOrderCreation();
    }

    public static void sendEmailsForReplenishmentOrders(List<Replenishment_Order__c> orders) {
        List<Replenishment_Order__c> updatedReplenishmentOrders = [SELECT Id,Order_Date__c, Name, Supplier__r.Name, Total_Line_Items__c,Total_Quantity__c  FROM Replenishment_Order__c WHERE Id IN :orders];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        // Query manager's email (assuming there is a manager field in User or related object)
        String managerEmail = [SELECT Email FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1].Email;

        for (Replenishment_Order__c order : updatedReplenishmentOrders) {
            system.debug('order ===>' + order);
            // Create an email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            // Set recipient
            email.setToAddresses(new List<String>{managerEmail});
            
            // Set email template subject and body
            email.setSubject('Approval Required for Replenishment Order ' + order.Name);
            email.setHtmlBody(
                'Dear Manager,<br><br>' +
                'The replenishment order <b>' + order.Name + '</b> has been created for supplier <b>' + order.Supplier__r.Name + '</b>. Below are the details:<br>' +
                '<ul>' +
                '<li><b>Order Date:</b> ' + order.Order_Date__c + '</li>' +
                '<li><b>Number of Items:</b> ' + order.Total_Line_Items__c + '</li>' +
                '<li><b>Total Quantity:</b> ' + order.Total_Quantity__c + '</li>' +
                '</ul><br>' +
                'Please respond to this email with one of the following:<br>' +
                '<ul>' +
                '<li><b>Approve</b>: To approve the replenishment order.</li>' +
                '<li><b>Reject</b>: To reject the replenishment order.</li>' +
                '</ul><br>' +
                'Thank you!<br><b>Stock Guardian System</b>'
            );
            
            // Add email to the list
            emails.add(email);
        }

        // Send emails
        Messaging.sendEmail(emails);
    }
}

