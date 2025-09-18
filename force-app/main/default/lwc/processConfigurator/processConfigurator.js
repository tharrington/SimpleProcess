import { LightningElement, wire, track, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import KONVA from '@salesforce/resourceUrl/Konva';
import getTemplates from '@salesforce/apex/ProcessConfiguratorCtrl.getTemplates';
import saveProcessTemplate from '@salesforce/apex/ProcessConfiguratorCtrl.saveProcessTemplate';
import getTemplateForEditing from '@salesforce/apex/ProcessConfiguratorCtrl.getTemplateForEditing';
import updateStepsToComplete from '@salesforce/apex/ProcessConfiguratorCtrl.updateStepsToComplete';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';



export default class ProcessConfigurator extends LightningElement {
    @api recordId;
    konvaInitialized = false;
    stage;
    layer;
    groups = [];
    selectedGroup = null;
    selectedConnection = null;
    connections = [];
    processName = '';
    stepsToComplete = '';

    GRID_SIZE = 20;
    selectedTemplateId = null;
    savedTemplateId = null;

    // Keep the original wired templates as read-only
    wiredTemplateData = [];
    
    // Create a separate mutable tracked property
    @track templates = [];
    @track templateLoadError;
    @track showEditModal = false;
    @track editStepsText = '';
    @track editTemplateId = null;
    @track showLogicModal = false;
    @track logicEditGroup = null;
    @track logicConditionInput = '';
    @track allowedStepIds = [];

    @wire(getTemplates)
    wiredTemplates({ error, data }) {
        if (data) {
            // Store the original wired data
            this.wiredTemplateData = data;
            // Create a mutable deep copy for this.templates
            this.templates = JSON.parse(JSON.stringify(data));
            this.templateLoadError = undefined;
        } else if (error) {
            this.templateLoadError = error;
            this.wiredTemplateData = [];
            this.templates = [];
        }
    }
    
    renderedCallback() {
        if (this.konvaInitialized) return;
        this.konvaInitialized = true;

        loadScript(this, KONVA)
            .then(() => {
                this.initializeCanvas();
                if (this.recordId && !this.hasLoaded) {
                    this.savedTemplateId = this.recordId;
                    this.loadTemplateData(this.recordId);
                    this.hasLoaded = true;
                }
            })
            .catch(error => {
                console.error('Failed to load Konva.js', error);
            });
    }

    /**   
     * initializeCanvas
     * Sets up the Konva stage and grid lines
     */    
    initializeCanvas() {
        const container = this.template.querySelector('.canvas');

        this.stage = new window.Konva.Stage({
            container: container,
            width: container.offsetWidth,
            height: 600
        });

        this.layer = new window.Konva.Layer();
        this.stage.add(this.layer);

        for (let i = 0; i < this.stage.width(); i += this.GRID_SIZE) {
            this.layer.add(new window.Konva.Line({
                points: [i, 0, i, this.stage.height()],
                stroke: '#eee',
                strokeWidth: 1
            }));
        }

        for (let j = 0; j < this.stage.height; j += this.GRID_SIZE) {
            this.layer.add(new window.Konva.Line({
                points: [0, j, this.stage.width(), j],
                stroke: '#eee',
                strokeWidth: 1
            }));
        }

        this.layer.draw();
    }

    /**
     * loadTemplateData
     * @param {*} templateId 
     */
    loadTemplateData(templateId) {
        getTemplateForEditing({ templateId })
            .then(data => {
                this.processName = data.processName;
                this.stepsToComplete = data.stepsToComplete;
                this.savedTemplateId = data.templateId;

                const stepMap = new Map();

                // Render steps
                data.steps.forEach(step => {
                    const group = this.addStep(step);
                    stepMap.set(step.id, group);
                });

                const logicNodes = new Map(); // cache: target step id -> logic group

                data.connections.forEach(conn => {
                    const from = stepMap.get(conn.fromStep);
                    const to   = stepMap.get(conn.toStep);
                    if (!from || !to) return;

                    const toStepData = data.steps.find(s => s.id === conn.toStep);

                    // If the target is governed by custom logic, insert the diamond BETWEEN from and to
                    if (toStepData?.inProgressRequirement === 'Custom Logic' && toStepData?.customLogic) {
                        let logicGroup = logicNodes.get(conn.toStep);

                        if (!logicGroup) {
                            const { w: fw, h: fh } = this.nodeDims(from);
                            const diamondX = from.x() + fw / 2 - 70;
                            const diamondY = from.y() + fh + 40;

                            logicGroup = this.addLogicStep({
                                id: `logic-for-${conn.toStep}`,
                                x: diamondX,
                                y: diamondY,
                                label: toStepData.customLogic,
                                condition: toStepData.customLogic
                            });
                            logicNodes.set(conn.toStep, logicGroup);

                            // ⚡ push target (and any steps below) down so they don't overlap the diamond
                            const shiftY = 200; // diamond (140) + padding
                            this.groups.forEach(g => {
                                if (g.y() >= to.y()) {
                                    g.y(g.y() + shiftY);
                                }
                            });

                            // diamond → target
                            this.drawArrow(logicGroup, to, 'green');
                        }

                        // from → diamond
                        this.drawArrow(from, logicGroup, 'green');
                    }  else {
                        // normal connection
                        this.drawArrow(from, to, 'black');
                    }
                });


                this.layer.draw();
                this.centerDiagramOnStage();
            })
            .catch(error => {
                console.error('Failed to load template data', error);
                this.showToast('Error', 'Failed to load process for editing.', 'error');
            });
    }


    extractStepIdsFromLogic(logic) {
        return logic.match(/\d+/g) || [];
    }

    nodeDims(node) {
        // All nodes are 140 wide; height differs
        return { w: 140, h: node?.condition === 'logic' ? 140 : 70 };
    }

    drawArrow(from, to, color = 'black') {
        const fromPos = from.position();
        const toPos   = to.position();

        const { w: fw, h: fh } = this.nodeDims(from);
        const { w: tw, h: th } = this.nodeDims(to);

        const fromCenterX = fromPos.x + fw / 2;
        const toCenterX   = toPos.x   + tw / 2;

        let fromY, toY;
        if (toPos.y > fromPos.y) {
            // downwards: bottom of from -> top of to
            fromY = fromPos.y + fh;
            toY   = toPos.y;
        } else {
            // upwards: top of from -> bottom of to
            fromY = fromPos.y;
            toY   = toPos.y + th;
        }

        const line = new window.Konva.Arrow({
            points: [fromCenterX, fromY, toCenterX, toY],
            pointerLength: 10,
            pointerWidth: 10,
            stroke: color,
            strokeWidth: 2,
            fill: color,
            hitStrokeWidth: 10,
            listening: true
        });

        line.on('click', () => {
            if (this.selectedConnection && this.selectedConnection !== line) {
            this.selectedConnection.stroke('black');
            this.selectedConnection.strokeWidth(2);
            this.selectedConnection.dash([]);
            }
            const isSelected = this.selectedConnection === line;
            if (isSelected) {
            line.stroke('black'); line.strokeWidth(2); line.dash([]); this.selectedConnection = null;
            } else {
            line.stroke('red'); line.strokeWidth(4); line.dash([10, 5]); this.selectedConnection = line;
            }
            this.layer.draw();
        });

        this.layer.add(line);
        this.connections.push({ from, to, line });
    }

    recomputeConnections() {
        this.connections.forEach(conn => {
            const fromPos = conn.from.position();
            const toPos   = conn.to.position();
            const { w: fw, h: fh } = this.nodeDims(conn.from);
            const { w: tw, h: th } = this.nodeDims(conn.to);

            const fromCenterX = fromPos.x + fw / 2;
            const toCenterX   = toPos.x   + tw / 2;

            let fromY, toY;
            if (toPos.y > fromPos.y) {
            fromY = fromPos.y + fh;
            toY   = toPos.y;
            } else {
            fromY = fromPos.y;
            toY   = toPos.y + th;
            }
            conn.line.points([fromCenterX, fromY, toCenterX, toY]);
        });
    }


    

    addLogicStep(logic = null) {
        const nextNumber = this.groups.filter(g => g.condition === 'logic')
            .map(g => parseInt(g.name().replace('logic-', '')))
            .filter(n => !isNaN(n)).length + 1;

        const logicId = logic?.id || `logic-${nextNumber}`;
        const labelText = logic?.label || logic?.condition || `Logic ${nextNumber}`;

        const group = new window.Konva.Group({
            x: logic?.x || 200,
            y: logic?.y || 100 + (nextNumber - 1) * 80,
            draggable: true,
            name: logicId
        });

        group.condition = 'logic';
        group.logicCondition = logic?.condition || '';

        // Put the diamond CENTER at (70,70) so its 140x140 bounds sit inside the group
        const diamond = new window.Konva.RegularPolygon({
            x: 70,
            y: 70,
            sides: 4,
            radius: 70,
            fill: '#ffa500',
            stroke: 'black',
            strokeWidth: 2,
            rotation: 90
        });

        const label = new window.Konva.Text({
            x: 0,
            y: 55,
            width: 140,
            align: 'center',
            text: labelText,
            fontSize: 14,
            fill: 'black'
        });

        group.add(diamond);
        group.add(label);
        group.diamondShape = diamond;

        this.layer.add(group);
        this.groups.push(group);

        group.on('click', () => this.handleGroupClick(group));
        group.on('dblclick', () => this.handleLogicEdit(group));

        group.on('dragmove', () => {
            const snappedX = Math.round(group.x() / this.GRID_SIZE) * this.GRID_SIZE;
            const snappedY = Math.round(group.y() / this.GRID_SIZE) * this.GRID_SIZE;
            group.position({ x: snappedX, y: snappedY });
            this.recomputeConnections();   // (uses the function below)
            this.layer.batchDraw();
        });

        this.layer.draw();
        return group;
    }




    addStep(step = null) {
        const usedNumbers = this.groups
            .map(g => parseInt(g.name().split('__')[0].replace('step-', '')))
            .filter(n => !isNaN(n))
            .sort((a, b) => a - b);

        let nextNumber = 1;
        while (usedNumbers.includes(nextNumber)) {
            nextNumber++;
        }

        let template;        
        let stepNumber = nextNumber;
        let stepName = `step-${stepNumber}__template-${this.selectedTemplateId}`;
        let templateId = this.selectedTemplateId;
        let labelText;

        if (step) {
            // Use provided step values
            stepNumber = step.stepNumber;
            stepName = step.id;
            templateId = step.templateId;
            labelText = step.label;
        } else {
            template = this.templates.find(t => t.Id === templateId);
            labelText = `Step ${stepNumber}\n${template?.Name || ''}`;
        }


        const group = new window.Konva.Group({
            x: step?.x || 50,
            y: step?.y || 10 + (nextNumber - 1) * 100,
            draggable: true,
            name: stepName
        });

        group.templateId = templateId;

        const box = new window.Konva.Rect({
            x: 0,
            y: 0,
            width: 140,
            height: 70,
            fill: '#0070d2',
            stroke: 'black',
            strokeWidth: 2,
            cornerRadius: 8
        });


        const label = new window.Konva.Text({
            x: 10,
            y: 10,
            text: labelText,
            fontSize: 14,
            fill: 'white'
        });

        group.add(box);
        group.add(label);
        this.layer.add(group);
        this.groups.push(group);

        group.on('click', () => this.handleGroupClick(group));

        group.on('dragmove', () => {
            const snappedX = Math.round(group.x() / this.GRID_SIZE) * this.GRID_SIZE;
            const snappedY = Math.round(group.y() / this.GRID_SIZE) * this.GRID_SIZE;
            group.position({ x: snappedX, y: snappedY });

            this.connections.forEach(conn => {
                if (conn.from === group || conn.to === group) {
                    const fromPos = conn.from.position();
                    const toPos = conn.to.position();

                    const fromCenterX = fromPos.x + 70;
                    const toCenterX = toPos.x + 70;

                    let fromY, toY;
                    if (toPos.y > fromPos.y) {
                        fromY = fromPos.y + 70;
                        toY = toPos.y;
                    } else {
                        fromY = fromPos.y;
                        toY = toPos.y + 70;
                    }

                    conn.line.points([fromCenterX, fromY, toCenterX, toY]);
                }
            });

            this.layer.batchDraw();
        });

        return group;
    }


    handleLogicEdit(group) {
        this.logicEditGroup = group;

        // Get all steps that connect into this logic node
        const incomingSteps = this.connections
            .filter(conn => conn.to === group && conn.from.templateId) // from must be a step
            .map(conn => {
                const nameParts = conn.from.name().split('__')[0]; // "step-1"
                const stepNumber = parseInt(nameParts.replace('step-', ''), 10);
                return stepNumber;
            })
            .filter(n => !isNaN(n));

        this.allowedStepIds = incomingSteps;
        this.logicConditionInput = group.logicCondition || '';
        this.showLogicModal = true;
    }


    /**
     * 
     * @returns 
     */
    saveProcess() {
        if (!this.processName) {
            this.showToast('Error', 'Please enter a process name.', 'error');
            return;
        }

        if (!this.stepsToComplete) {
            this.showToast('Error', 'Please enter steps to complete.', 'error');
            return;
        }

        // Map of stepId => logic condition string
        const logicTargets = new Map();

        this.connections.forEach(conn => {
            if (conn.from.condition === 'logic') {
                logicTargets.set(conn.to.name(), conn.from.logicCondition || '');
            }
        });

        const steps = this.groups.map(group => {
            const labelNode = group.findOne(node => node.className === 'Text');
            const base = {
                id: group.name(),
                x: group.x(),
                y: group.y(),
                label: labelNode?.text() || ''
            };

            if (group.condition === 'logic') {
                return {
                    ...base,
                    type: 'logic',
                    condition: group.logicCondition || ''
                };
            } else {
                const nameParts = group.name().split('__')[0]; // "step-1"
                const stepNumber = parseInt(nameParts.replace('step-', ''), 10);
                const templateId = group.templateId;

                const logicCondition = logicTargets.get(group.name()); // may be undefined

                return {
                    ...base,
                    type: 'step',
                    stepNumber,
                    templateId,
                    inProgressRequirement: logicCondition ? 'Custom Logic' : 'Previous Step Completed',
                    customLogic: logicCondition || null
                };
            }
        });

        const connections = this.connections.map(conn => {
            return {
                fromStep: conn.from.name(),
                toStep: conn.to.name(),
                toTemplateId: conn.to.templateId
            };
        });

        const connectedStepIds = new Set();
        this.connections.forEach(conn => {
            connectedStepIds.add(conn.from.name());
            connectedStepIds.add(conn.to.name());
        });

        const disconnectedGroups = this.groups.filter(group => !connectedStepIds.has(group.name()));

        if (disconnectedGroups.length > 0) {
            const disconnectedNames = disconnectedGroups.map(g => g.name()).join(', ');
            this.showToast('Error', `You must connect all steps`, 'error');
            return;
        }

        const payload = {
            processName: this.processName,
            stepsToComplete: this.stepsToComplete,
            templateId: this.savedTemplateId,
            steps,
            connections
        };

        const payloadJson = JSON.stringify(payload);
        console.log('### Sending Payload:', payloadJson);

        saveProcessTemplate({ payloadJson })
            .then((templateId) => {
                this.savedTemplateId = templateId;
                this.showToast('Success', 'Process saved successfully.', 'success');
            })
            .catch((error) => {
                console.error('Error saving process:', error);
                this.showToast('Error', error.body?.message || 'Save failed', 'error');
            });
    }


    /**
     * HELPER METHODS
     */
    highlightGroup(group, isActive) {
        const rect = group.findOne(node => node.className === 'Rect');
        const diamond = group.diamondShape;

        if (rect) {
            rect.fill(isActive ? '#28a745' : '#0070d2');
            rect.stroke(isActive ? 'darkgreen' : 'black');
        }

        if (diamond) {
            diamond.fill(isActive ? 'green' : '#ffa500');
            diamond.stroke(isActive ? 'darkgreen' : 'black');
        }
    }


    get templateOptions() {
        return this.templates.map(t => ({
            label: t.Name,
            value: t.Id
        }));
    }

    handleTemplateChange(event) {
        this.selectedTemplateId = event.detail.value;
    }

    handleProcessNameChange(event) {
        this.processName = event.detail.value;
    }

    handleStepsToCompleteChange(event) {
        this.stepsToComplete = event.detail.value;
    }

    handleAddStep() {
        if (!this.selectedTemplateId) {
            alert('Please select a template before adding a step.');
            return;
        }
        this.addStep();
    }

    handleAddLogic() {
        if (!this.layer) {
            this.showToast('Error', 'Canvas is not ready yet. Try again in a moment.', 'error');
            return;
        }
        this.addLogicStep();
    }


    renumberSteps() {
        this.groups.forEach((group, index) => {
            const stepNum = index + 1;
            const templateId = group.templateId;
            const template = this.templates.find(t => t.Id === templateId);

            const newName = `step-${stepNum}__template-${templateId}`;
            group.name(newName);

            const label = group.findOne(node => node.className === 'Text');
            if (label) {
                label.text(`Step ${stepNum}\n${template?.Name || ''}`);
            }
        });

        this.layer.draw();
    }

    handleGroupClick(clickedGroup) {
        if (this.selectedConnection) {
            this.selectedConnection.stroke('black');
            this.selectedConnection.strokeWidth(2);
            this.selectedConnection.dash([]);
            this.selectedConnection = null;
        }
        

        if (!this.selectedGroup) {
            this.selectedGroup = clickedGroup;
            this.highlightGroup(clickedGroup, true);
            return;
        }

        if (this.selectedGroup === clickedGroup) {
            this.highlightGroup(clickedGroup, false);
            this.selectedGroup = null;
            return;
        }

        const alreadyConnected = this.connections.some(
            conn => conn.from === this.selectedGroup && conn.to === clickedGroup
        );

        if (!alreadyConnected) {
            const fromPos = this.selectedGroup.position();
            const toPos = clickedGroup.position();

            const fromCenterX = fromPos.x + 70;
            const toCenterX = toPos.x + 70;

            let fromY, toY;
            if (toPos.y > fromPos.y) {
                fromY = fromPos.y + 70;
                toY = toPos.y;
            } else {
                fromY = fromPos.y;
                toY = toPos.y + 70;
            }

            const line = new window.Konva.Arrow({
                points: [fromCenterX, fromY, toCenterX, toY],
                pointerLength: 10,
                pointerWidth: 10,
                stroke: 'black',
                strokeWidth: 2,
                fill: 'black',
                hitStrokeWidth: 10,
                listening: true
            });

            line.on('click', () => {
                if (this.selectedConnection && this.selectedConnection !== line) {
                    this.selectedConnection.stroke('black');
                    this.selectedConnection.strokeWidth(2);
                    this.selectedConnection.dash([]);
                }

                const isSelected = this.selectedConnection === line;
                if (isSelected) {
                    line.stroke('black');
                    line.strokeWidth(2);
                    line.dash([]);
                    this.selectedConnection = null;
                } else {
                    line.stroke('red');
                    line.strokeWidth(4);
                    line.dash([10, 5]);
                    this.selectedConnection = line;
                }

                this.layer.draw();
            });

            this.layer.add(line);
            this.connections.push({ from: this.selectedGroup, to: clickedGroup, line });
        }

        this.highlightGroup(this.selectedGroup, false);
        this.selectedGroup = null;
        this.layer.draw();
    }

    handleDeleteConnection() {
        if (this.selectedConnection) {
            this.selectedConnection.destroy();
            this.connections = this.connections.filter(c => c.line !== this.selectedConnection);
            this.selectedConnection = null;
            this.layer.draw();
        } else if (this.selectedGroup) {
            const group = this.selectedGroup;

            this.connections = this.connections.filter(conn => {
                const isLinked = conn.from === group || conn.to === group;
                if (isLinked) conn.line.destroy();
                return !isLinked;
            });

            group.destroy();
            this.groups = this.groups.filter(g => g !== group);
            this.selectedGroup = null;

            this.renumberSteps();
        } else {
            console.warn('⚠️ Nothing selected to delete.');
        }
    }

    handlePrint() {
        const steps = this.groups.map(group => {
            const labelNode = group.findOne(node => node.className === 'Text');
            return {
                id: group.name(),
                label: labelNode?.text() || '',
                x: group.x(),
                y: group.y(),
                templateId: group.templateId
            };
        });

        const lines = this.connections.map(conn => ({
            from: conn.from.name(),
            to: conn.to.name()
        }));
        console.log(JSON.stringify({ steps, connections: lines }, null, 2));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    handleEditStepsClick() {
        if (!this.selectedGroup?.templateId) return;

        const templateId = this.selectedGroup.templateId;
        this.editTemplateId = templateId;

        const selectedTemplate = this.templates.find(t => t.Id === templateId);
        this.editStepsText = selectedTemplate?.Steps_To_Complete__c || '';
        this.showEditModal = true;
    }

    handleStepsInputChange(event) {
        this.editStepsText = event.detail.value;
    }

    handleModalEditCancel(event) {
        this.showEditModal = false;
    }

    handleSaveSteps() {
        const body = {
            templateId: this.editTemplateId,
            stepsToComplete: this.editStepsText
        };

        console.log(`### body ${JSON.stringify(body)}`);

        updateStepsToComplete(body)
            .then(() => {
                console.log(`### Steps to Complete updated for template ${JSON.stringify(this.templates)}`);
                // Update local array so UI stays in sync
                const idx = this.templates.findIndex(t => t.Id === this.editTemplateId);
                console.log(`### idx ${idx}`);

                if (idx !== -1) {
                    console.log(`### this.templates[idx] before: ${JSON.stringify(this.templates[idx])}`);
                    
                    // Now this will work because this.templates is mutable
                    this.templates[idx] = {
                        ...this.templates[idx],
                        Steps_To_Complete__c: this.editStepsText
                    };
                    
                    console.log(`### this.templates[idx] after: ${JSON.stringify(this.templates[idx])}`);
                }

                this.showToast('Success', 'Steps to Complete updated.', 'success');
                this.showEditModal = false;
            })
            .catch(error => {
                console.error('Error saving steps to complete:', error);
                this.showToast('Error', 'Save failed.', 'error');
            });
    }

    get showEditButton() {
        return this.selectedGroup?.templateId != null;
    }

    get allowedStepIdsText() {
        return this.allowedStepIds.join(', ');
    }


    /**
     * Modal handlers
     */
    handleLogicConditionChange(event) {
        this.logicConditionInput = event.detail.value;
    }

    handleLogicModalCancel() {
        this.showLogicModal = false;
        this.logicEditGroup = null;
        this.logicConditionInput = '';
    }

    handleLogicModalSave() {
        const input = this.logicConditionInput.trim();
        const usedIds = new Set(this.allowedStepIds.map(n => String(n)));

        // Basic validation: only allow allowed step numbers in the logic string
        const referenced = input.match(/\b\d+\b/g) || [];
        const invalid = referenced.filter(id => !usedIds.has(id));

        if (invalid.length > 0) {
            this.showToast('Error', `Invalid step(s) used: ${invalid.join(', ')}`, 'error');
            return;
        }

        this.logicEditGroup.logicCondition = input;

        const label = this.logicEditGroup.findOne(node => node.className === 'Text');
        if (label) {
            label.text(`Logic\n${input}`);
        }

        this.layer.draw();

        // Clean up modal state
        this.showLogicModal = false;
        this.logicEditGroup = null;
        this.logicConditionInput = '';
    }

    // Compute the bounding box of all nodes you drew
    computeDiagramBounds() {
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;

        this.groups.forEach(g => {
            const { w, h } = this.nodeDims(g);
            minX = Math.min(minX, g.x());
            minY = Math.min(minY, g.y());
            maxX = Math.max(maxX, g.x() + w);
            maxY = Math.max(maxY, g.y() + h);
        });

        if (!isFinite(minX)) return { minX: 0, minY: 0, width: 0, height: 0 };
        return { minX, minY, width: maxX - minX, height: maxY - minY };
    }

    // Shift everything so the diagram is centered on the stage
    centerDiagramOnStage(padding = 24) {
        const bounds = this.computeDiagramBounds();
        if (bounds.width === 0 && bounds.height === 0) return;

        const stageW = this.stage.width();
        const stageH = this.stage.height();

        // Target top-left for diagram (centered, with padding floor)
        const targetX = Math.max(padding, (stageW - bounds.width) / 2);
        const targetY = Math.max(padding, (stageH - bounds.height) / 2);

        const offsetX = targetX - bounds.minX;
        const offsetY = targetY - bounds.minY;

        // Move all groups
        this.groups.forEach(g => g.position({ x: g.x() + offsetX, y: g.y() + offsetY }));

        // Update all lines
        this.recomputeConnections();

        this.layer.draw();
    }

}
