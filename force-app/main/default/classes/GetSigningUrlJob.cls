public class GetSigningUrlJob implements Queueable, Database.AllowsCallouts {

    private dfsle.UUID envelopeId;
    private String returnUrl;

    public GetSigningUrlJob(dfsle.UUID envelopeId, String returnUrl) {
        this.envelopeId = envelopeId;
        this.returnUrl = returnUrl;
    }

    public void execute(QueueableContext context) {
        try {
            Url signingUrl = dfsle.SigningService.getEmbeddedSigningUrl(
                envelopeId,
                new Url(returnUrl)
            );

            System.debug('✅ Embedded Signing URL: ' + signingUrl.toExternalForm());

            // Optionally: Email it or store it

        } catch (Exception e) {
            System.debug('GetSigningUrlJob error: ' + e.getMessage());
            System.debug('Trace: ' + e.getStackTraceString());
        }
    }
}