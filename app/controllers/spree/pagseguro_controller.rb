module Spree
  class PagseguroController < Spree::StoreController
    skip_before_action :verify_authenticity_token, only: :notify

    def callback
      @order = Spree::Order.find_by_number(params[:order])

      pagseguro_transaction = Spree::PagseguroTransaction.find_by_order_id(@order.id.to_s)
      pagseguro_transaction.update_attribute :status, 'waiting'

      redirect_to spree.order_path(@order)
    end

    def notify
      logger.info "[PAGSEGURO] Gateway is calling /notify"
      logger.info params

      notification = Spree::PagseguroTransaction.update_last_transaction(params)
      payment_method = Spree::PaymentMethod.where(type: 'Spree::BillingIntegration::Pagseguro::Checkout').first

      @order = Spree::Order.find_by_number(notification.reference)
      payment = @order.payments.where(:payment_method_id => payment_method.id).last

      payment.started_processing!
      if notification.approved?
        logger.info "[PAGSEGURO] Order #{@order.number} approved"
        payment.complete!
        @order.next
      else
        logger.info "[PAGSEGURO] Order #{@order.number} failed"
        payment.pend!
      end

      render nothing: true, head: :ok
    end

  end
end
