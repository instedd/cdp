var BaseEncounterForm = {
  getInitialState: function() {
		var user_email='';
		if (this.props.encounter["user"] != null) {
			user_email= this.props.encounter["user"].email
		};
		
    return {
      encounter: this.props.encounter,
      manual_sample_entry: this.props.manual_sample_entry,
      user_email: user_email
    };
  },

  componentWillReceiveProps: function(nextProps) {
    this.setState({encounter: nextProps.encounter});
  },

  save: function() {
    var callback = function() {
      window.location.href = '/encounters/' + this.state.encounter.id;
    };

    if (this.state.encounter.id) {
      this._ajax('PUT', '/encounters/' + this.state.encounter.id, callback);
    } else {
      this._ajax('POST', '/encounters', callback);
    }
  },

  addNewSamples: function(event) {
    if(this.state.manual_sample_entry) {
      this.refs.addNewSamplesModal.show();
    } else {
      this._ajax_put('/encounters/add/new_sample');
    }
    event.preventDefault();
  },

  closeAddNewSamplesModal: function (event) {
    this.refs.addNewSamplesModal.hide();
    event.preventDefault();
  },

  validateAndSetManualEntry: function (event) {
    var sampleId = React.findDOMNode(this.refs.manualSampleEntry).value;
    if(this.state.encounter.new_samples.filter(function(el){return el.entity_id == sampleId}).length > 0) {
      // Error handling as done in the ajax responses
      alert("This sample has already been added");
    } else {
      this._ajax_put('/encounters/add/manual_sample_entry', function() {
        this.refs.addNewSamplesModal.hide();
      }, {entity_id: sampleId});
    }
    event.preventDefault();
  },

  removeNewSample: function(sample) {
    var filtered = _.filter(this.state.encounter.new_samples, function(s) { return s.entity_id != sample.entity_id });

    this.setState(React.addons.update(this.state, {
      encounter : { new_samples: { $set : filtered }},
    }));
  },

  _ajax_put: function(url, success, extra_data) {
    this._ajax('PUT', url, success, extra_data);
  },

  _ajax: function(method, url, success, extra_data) {
    var _this = this;
    $.ajax({
      url: url,
      method: method,
      data: _.extend({ encounter: JSON.stringify(this.state.encounter), context: this.props.context.full_context }, extra_data),
      success: function (data) {
        if (data.status == 'error') {
          alert(data.message); //TODO show errors nicely
        } else {
          _this.setState(React.addons.update(_this.state, {
            encounter: { $set: data.encounter }
          }), function(){
            if (data.status == 'ok' && success) {
              success.call(_this, data);
            }
          });
        }
      }
    });
  },
}

var EncounterForm = React.createClass(_.merge({

  showAddSamplesModal: function(event) {
    this.refs.addSamplesModal.show()
    event.preventDefault()
  },

  closeAddSamplesModal: function (event) {
    this.refs.addSamplesModal.hide();
    event.preventDefault();
  },

  showUnifySamplesModal: function(sample) {
    this.setState(React.addons.update(this.state, {
      unifyingSample: { $set: sample }
    }));

    this.refs.unifySamplesModal.show()
    event.preventDefault()
  },

  closeUnifySamplesModal: function (event) {
    this.refs.unifySamplesModal.hide();
    event.preventDefault();
  },

  unifySample: function(sample) {
    this.refs.unifySamplesModal.hide();
    this._ajax_put("/encounters/merge/sample/", null, { sample_uuids: [this.state.unifyingSample.uuid, sample.uuid] });
  },

  appendSample: function(sample) {
    this.refs.addSamplesModal.hide()
    this._ajax_put("/encounters/add/sample/" + sample.uuid);
  },

  showTestsModal: function(event) {
    this.refs.testsModal.show()
    event.preventDefault()
  },

  closeTestsModal: function(event) {
    this.refs.testsModal.hide()
    event.preventDefault()
  },
  
  appendTest: function(test) {
    this.refs.testsModal.hide()
    this._ajax_put("/encounters/add/test/" + test.uuid);
  },

  encounterChanged: function(field){
    return function(event) {
      var newValue = event.target.value;
      this.setState(React.addons.update(this.state, {
        encounter : { [field] : { $set : newValue } }
      }));
    }.bind(this);
  },

  encounterAssayChanged: function(index, field){
    return function(event) {
      var newValue;

      if (field == 'result') {
        newValue = event;
      } else {
        newValue = event.target.value;
      }

      this.setState(React.addons.update(this.state, {
        encounter : { assays : { [index] : { [field] : { $set : newValue } } } }
      }));
    }.bind(this);
  },
  render: function() {
    var diagnosisEditor = null;

    var assayResultOptions = _.map(this.props.possible_assay_results, function(v){return {value: v, label: _.capitalize(v)};})
    if (this.state.encounter.assays.length > 0) {
      diagnosisEditor = (
        <div className="row">
          <div className="col pe-2">
            <label>Diagnosis</label>
            <p style={{fontSize: "12px"}}><i>When new tests are reported for this order, you'll be able to diagnose the corresponding condition here.</i></p>
          </div>

          <div className="col assays-editor">
            {this.state.encounter.assays.map(function(assay, index){
              assay.result = assay.result;
              return (
                <div className="row" key={index}>
                  <div className="col px-4">
                    <div className="underline">
                      <span>{assay.condition.toUpperCase()}</span>
                    </div>
                  </div>
                  <div className="col px-2">
                    <Select value={assay.result} options={assayResultOptions} onChange={this.encounterAssayChanged(index, 'result')} clearable={false} className="input-block"/>
                  </div>
                  <div className="col px-2">
                    <input type="text" className="quantitative pull-right" value={assay.quantitative_result} placeholder="Quant." onChange={this.encounterAssayChanged(index, 'quantitative_result')} />
                  </div>
                </div>
              );
            }.bind(this))}
            <div className="row">
              <div className="col px-6">
                <textarea className="observations input-block" value={this.state.encounter.observations} placeholder="Observations" onChange={this.encounterChanged('observations')} />
              </div>
            </div>
          </div>
        </div>);
      } else {
        diagnosisEditor = null;
      }

      return (
        <div>
          {(function(){
            if (this.state.encounter.id == null) return;

            return (
              <div>
                <div className="row">
                  <div className="col pe-2">
                    <label>Site</label>
                  </div>
                  <div className="col">
                    <p>{this.props.encounter.site.name}</p>
                  </div>
                </div>

                <div className="row">
                  <div className="col pe-2">
                    <label>Test Order ID</label>
                  </div>
                  <div className="col">
                    <p>{this.props.encounter.uuid}</p>
                  </div>
                </div>

								<div className="row">
                  <div className="col pe-2">
                    <label>Requested By:</label>
                  </div>
                  <div className="col">
                    <p>{this.state.user_email}</p>
                  </div>
                </div>



                <div className="row">
                  <div className="col pe-2">
                    <label>Reason For:</label>
                  </div>
                  <div className="col">
                    <p>{this.props.encounter.exam_reason}</p>
                  </div>
                </div>


                <div className="row">
                  <div className="col pe-2">
                    <label>Diagnosis Comment:</label>
                  </div>
                  <div className="col">
                    <p>{this.props.encounter.diag_comment}</p>
                  </div>
                </div>


                <div className="row">
                  <div className="col pe-2">
                    <label>Weeks In Treatment:</label>
                  </div>
                  <div className="col">
                    <p>{this.props.encounter.treatment_weeks}</p>
                  </div>
                </div>


                <div className="row">
                  <div className="col pe-2">
                    <label>Tests Requested:</label>
                  </div>
                  <div className="col">
                    <p>{this.props.encounter.tests_requested}</p>
                  </div>
                </div>


                <div className="row">
                  <div className="col pe-2">
                    <label>Sample Type:</label>
                  </div>
                  <div className="col">
                    <p>{this.props.encounter.coll_sample_type}</p>
                  </div>
                </div>

                <div className="row">
                  <div className="col pe-2">
                    <label>Sample comment:</label>
                  </div>
                  <div className="col">
                    <p>{this.props.encounter.coll_sample_other}</p>
                  </div>
                </div>

                <div className="row">
                  <div className="col pe-2">
                    <label>Test Due Date:</label>
                  </div>
                  <div className="col">
                    <p>{this.props.encounter.testdue_date}</p>
                  </div>
                </div>


              </div>);

            }.bind(this))()}


            <FlexFullRow>
              <PatientCard patient={this.state.encounter.patient} />
            </FlexFullRow>

           <br />

            <FlexFullRow>
              <button type="button" className="btn-primary" onClick={this.save}>Save</button>
            </FlexFullRow>

          </div>
        );
      },

    }, BaseEncounterForm));
