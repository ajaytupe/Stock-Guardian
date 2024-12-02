import { LightningElement, track, wire } from 'lwc';
import createSalesOrderWithLineItems from '@salesforce/apex/SalesOrderController.createSalesOrderWithLineItems';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import SALES_ORDER_OBJECT from '@salesforce/schema/Sales_Order__c';
import PAYMENT_TYPE_FIELD from '@salesforce/schema/Sales_Order__c.Payment_Type__c';
import getInventoryItems from '@salesforce/apex/SalesOrderController.getInventoryItems';

export default class SalesOrderForm extends LightningElement {
    @track salesOrder = { 
        Payment_Type__c: '', 
        Sales_Representative_ID__c: '', 
        Sale_Date__c: '', 
        Discount__c: '', 
        Store__c: '', 
        Total_Amount__c: '' // Add Total Amount if it's part of salesOrder
    };
    
    @track lineItems = [
        { id: 1, Inventory_Item__c: '', Quantity__c: '' },
    ];
    @track paymentTypeOptions = [];
    @track inventoryItemOptions = [];
    @track isLoading = false;  // Add loading state
    lineItemCounter = 1; // Counter for sequential IDs

    @wire(getObjectInfo, { objectApiName: SALES_ORDER_OBJECT })
    salesOrderInfo;

    @wire(getPicklistValues, { recordTypeId: '$salesOrderInfo.data.defaultRecordTypeId', fieldApiName: PAYMENT_TYPE_FIELD })
    wiredPaymentTypeValues({ error, data }) {
        if (data) {
            this.paymentTypeOptions = data.values;
        } else if (error) {
            console.error('Error fetching Payment_Type__c picklist values:', error);
        }
    }    

    handleSalesOrderChange(event) {
        const field = event.target.name;
        this.salesOrder[field] = event.target.value;
        // If Store__c changes, fetch new inventory items
        if (field === 'Store__c') {
            const storeId = event.target.value;
            this.fetchInventoryItems(storeId);
        }
    }

    async fetchInventoryItems(storeId) {
        this.isLoading = true;  // Start loading
    
        try {
            // Correct the Apex method call, ensuring no duplicate declarations
            const data = await getInventoryItems({ storeID: storeId }); // Corrected parameter name
    
            // Map the response to create options for combobox
            this.inventoryItemOptions = data.map(item => ({ label: item.Name, value: item.Id }));
        } catch (error) {
            this.inventoryItemOptions = []; // Clear options if there's an error
        } finally {
            this.isLoading = false;  // Stop loading
        }
    }
    

    handleLineItemChange(event) {
        const index = event.target.dataset.index;
        const field = event.target.name;
        this.lineItems[index][field] = event.target.value;
    }

    addLineItem() {
        this.lineItemCounter += 1; // Increment the counter for a unique sequential ID
        this.lineItems.push({ id: this.lineItemCounter, Inventory_Item__c: '', Quantity__c: '' });
    }

    saveRecords() {
        // Remove the `id` field before passing lineItems to Apex
        const lineItemsForApex = this.lineItems.map(({ id, ...rest }) => rest);
    
        createSalesOrderWithLineItems({ salesOrder: this.salesOrder, lineItems: lineItemsForApex })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Sales Order and Line Items created successfully',
                        variant: 'success',
                    })
                );
                this.resetForm();
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error',
                    })
                );
            });
    }

    

    resetForm() {
        this.salesOrder = { Payment_Type__c: '', Sales_Representative_ID__c: '', Sale_Date__c: '', Discount__c: '', Store__c: '' };
        this.lineItems = [{ id: 1, Inventory_Item__c: '', Quantity__c: '' }];
        this.lineItemCounter = 1; // Reset the counter
        this.inventoryItemOptions = []; // Clear inventory options on reset
    }
}
