var UploadCsvBox = React.createClass({
  getInitialState: function() {
    return {
      csrfToken: this.props.csrf_token,
      url: "/csv_validation/" + this.props.context,
      fieldName: this.props.name, // Initial fieldName value
      uploadRows: [] // Array to store upload rows
    };
  },

  handleChange: function(event) {
    const file = event.target.files[0];
    const formData = new FormData();
    formData.append('csv_file', file);

    fetch(this.state.url, {
      method: "POST",
      headers: {
        "X-CSRF-Token": this.state.csrfToken
      },
      body: formData
    })
      .then(response => {
        if (response.ok) {
          return response.json();
        } else {
          throw new Error("Request failed. Status: " + response.status);
        }
      })
      .then(responseJson => {
        const found_batches = responseJson.found_batches;
        const not_found_batches = responseJson.not_found_batches;
        const batches_nbr = responseJson.batches_nbr;
        console.log(not_found_batches.map(batch => batch.uuid))

        // Create row from template with filename and upload info
        const filename = file.name;
        const uploadInfo = {
          uploadedSamplesCount: found_batches.length,
          notFoundUuids: not_found_batches
        };

        // Add the new row to the state
        this.setState(prevState => ({
          uploadRows: [...prevState.uploadRows, {filename, uploadInfo, showTooltip: false}]
        }));

      })
      .catch(error => {
        console.log("Error:", error);
      });
  },

  handleClick: function(index) {
    // Toggle the showTooltip state
    this.setState(prevState => {
      const newRows = [...prevState.uploadRows];
      newRows[index].showTooltip = !newRows[index].showTooltip;
      return {uploadRows: newRows};
    });

    // Hide the tooltip after 5 seconds
    if (!this.state.uploadRows[index].showTooltip) {
      setTimeout(() => {
        this.setState(prevState => {
          const newRows = [...prevState.uploadRows];
          newRows[index].showTooltip = false;
          return {uploadRows: newRows};
        });
      }, 5000);
    }
  },
  handleRemove: function(index) {
    // Remove the row from the state
    this.setState(prevState => {
      const newRows = [...prevState.uploadRows];
      newRows.splice(index, 1);
      return {uploadRows: newRows};
    });

    // Display the add-box-file element
    // Note: This assumes that there's a corresponding element in the render method with the id 'add-box-file'
    this.setState({displayAddBoxFile: true});
  },

  renderUploadRow: function(rowData, index) {
  const { filename, uploadInfo, showTooltip } = rowData;
  const { uploadedSamplesCount, notFoundUuids } = uploadInfo;
  const batchesNotFound = notFoundUuids.length;
  const batchesText = batchesNotFound > 1 ? 'batches' : 'batch';
  const samplesText = uploadedSamplesCount > 1 ? 'samples' : 'sample';

  const tooltipText = notFoundUuids.slice(0, 5).join("<br>");

  return (
    <div className="items-row" key={filename}>
      <div className="items-item gap-5">
        <div className="icon-circle-minus icon-gray remove_file" onClick={() => this.handleRemove(index)}></div>
        <div className="file-name">{filename}</div>
      </div>
      <div className={`items-row-action gap-5 not_found_message ${batchesNotFound > 0 ? 'ttip input-required' : ''}`}
           onClick={() => this.handleClick(index)}>
        <div className="uploaded-samples-count">
          {uploadedSamplesCount} {samplesText}
          {batchesNotFound > 0 && (
            <span className="dashed-underline">
              {" ("}{batchesNotFound} {batchesText} not found{")"}
            </span>
          )}
        </div>
        <div className={`upload-icon bigger ${batchesNotFound > 0 ? 'icon-alert icon-red' : 'icon-check'}`}></div>
        {batchesNotFound > 0 && (
          <div className={`ttext not-found-uuids ${showTooltip ? '' : 'hidden'}`}>
            {tooltipText}
          </div>
        )}
      </div>
    </div>
  );
},

  render: function() {
    return (
    <span className="btn-upload">
        <input
          type="file"
          name="box[csv_box]"
          className="csv_file"
          accept="text/csv"
          onChange={this.handleChange}
        />
        {this.state.uploadRows.map(this.renderUploadRow)}
        </span>
    );
  }
});
