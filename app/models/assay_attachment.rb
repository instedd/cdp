class AssayAttachment < ActiveRecord::Base
  belongs_to :loinc_code
  belongs_to :sample
  has_one :assay_file, dependent: :destroy
  accepts_nested_attributes_for :assay_file, allow_destroy: true

  # @todo CREATE RAKE TASK TO MOVE CURRENT PICTURES TO ASSAY_FILES TABLE AND CREATE THE RELATION WITH ASSAY_ATTACHMENT
  # @todo CREATE MIGRATION FOR REMOVING PICTURE COLUMN
  # has_attached_file :picture, styles:  lambda { |a| a.instance.is_image? ? { :card => "130x130>" }  : {} }

  def is_image?
    self.assay_file.picture.content_type =~ /\Aimage\/.*\Z/
  end

  def picture
    self.assay_file.picture
  end

end
