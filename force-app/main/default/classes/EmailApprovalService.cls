global class EmailApprovalService implements Messaging.InboundEmailHandler {
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        try {
            // Extract email body and trim whitespace
            String emailBody = email.plainTextBody.trim().toLowerCase();
            String approvalAction;

            // Determine action based on email content
            if (emailBody.contains('approve')) {
                approvalAction = 'Approve';
            } else if (emailBody.contains('reject')) {
                approvalAction = 'Reject';
            } else {
                throw new EmailApprovalException('Invalid response. Please reply with "Approve" or "Reject".');
            }

            // Extract record name from email subject
            String recordName = extractRecordName(email.subject);
            if (String.isEmpty(recordName)) {
                throw new EmailApprovalException('Record Name not found in the email.');
            }

            // Query the ProcessInstanceWorkitem by TargetObject.Name
            ProcessInstanceWorkitem workItem = [
                SELECT Id, ProcessInstance.TargetObjectId
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObject.Name = :recordName
                LIMIT 1
            ];

            // Submit the approval or rejection
            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setComments('Response processed via email.');
            req.setWorkItemId(workItem.Id);
            req.setAction(approvalAction);

            Approval.ProcessResult processResult = Approval.process(req);

            // Check if the process was successful
            if (!processResult.isSuccess()) {
                throw new EmailApprovalException('Approval process failed for Record Name: ' + recordName);
            }

            System.debug('Approval processed successfully for Record Name: ' + recordName);
        } catch (EmailApprovalException e) {
            System.debug('Custom error: ' + e.getMessage());
        } catch (Exception e) {
            System.debug('Unexpected error: ' + e.getMessage());
        }

        result.success = true; // Ensure the email doesn't bounce back
        return result;
    }

    // Extract the record name from the email subject
    private String extractRecordName(String subject) {
        // Example: Extract "SO-001" from subject like "Approval Request for SO-001"
        Pattern recordNamePattern = Pattern.compile('ROID-[0-9]+'); // Adjust pattern to match your auto-number format
        Matcher matcher = recordNamePattern.matcher(subject);
        return matcher.find() ? matcher.group(0) : null;
    }

    // Define a custom exception class
    public class EmailApprovalException extends Exception {}
}
