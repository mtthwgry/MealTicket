class Customer
  FROM_PHONE_NUMBER = "+13123131171"

  attr_reader :email, :card, :stripe_customer

  def initialize(options)
    @options = options
    @email = options[:email]
    @card = options[:card]
  end

  def finalize_purchase(purchase, amount, promotion)
    create_in_stripe!
    charge!(amount, description: promotion)
    purchase.confirm!
    send_confirmation_message!(purchase)
  end

  def create_in_stripe!
    @stripe_customer = Stripe::Customer.create(
      :email => self.email,
      :card  => self.card
    )
  end

  def charge!(amount, options={})
    Stripe::Charge.create(
      :customer    => self.stripe_customer.id,
      :amount      => amount,
      :description => options.fetch(:description, ""),
      :currency    => 'usd'
    )
  end

  def send_confirmation_message!(purchase)
    # does this raise an exception? or mutate state? and if not, it shouldn't be a banger
    # is there an option for refiring an unsent message?
    client.messages.create({
      from: FROM_PHONE_NUMBER,
      to:   purchase.phone_number,
      body: body(purchase)
    })
  end

  def client
    @_client ||= Twilio::REST::Client.new
  end

  def body(purchase)
    <<-MSG
Hey #{purchase.purchaser_name},

Thanks buying choosing MealTicket for #{purchase.ticket.promotion.restaurant.name} for a group of #{purchase.ticket.group_size}. Your confirmation number is: #{purchase.confirmation_id}.

Enjoy your meal!
    MSG
  end
end
