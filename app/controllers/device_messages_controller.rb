class DeviceMessagesController < ApplicationController
  layout "institutions"
  set_institution_tab :devices

  before_filter :load_institution
  before_filter :load_device
  before_filter :load_message, only: [:raw, :reprocess]

  def index
    @messages = @device.device_messages
  end

  def raw
    ext, type = case @device.current_manifest.data_type
    when 'json'
      ['json', 'application/json']
    when 'csv', 'headless_csv'
      ['csv', 'text/csv']
    when 'xml'
      ['xml', 'application/xml']
    else
      ['txt', 'text/plain']
    end

    send_data @message.plain_text_data, filename: "message_#{@message.id}.#{ext}", type: type
  end

  def reprocess
    @message.reprocess
    redirect_to institution_device_device_messages_path(@institution, @device),
                notice: 'The message will be reprocessed'
  end

  private

  def load_institution
    @institution = Institution.find params[:institution_id]
    authorize_resource(@institution, READ_INSTITUTION)
  end

  def load_device
    @device = @institution.devices.find params[:device_id]
    authorize_resource(@device, READ_DEVICE)
  end

  def load_message
    @message = @device.device_messages.find(params[:id])
  end
end
