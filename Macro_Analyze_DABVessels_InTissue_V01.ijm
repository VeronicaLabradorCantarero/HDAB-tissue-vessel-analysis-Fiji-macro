//CNIC Microscopy Unit 2023
//=========================
//https://www.cnic.es/es/investigacion/microscopia

//Measures Area and %Area of signal in Tissue
//Detects and measures area of vessels
//Uses HDAB vector of Color Deconvolution V1 plugin (https://blog.bham.ac.uk/intellimic/g-landini-software/colour-deconvolution-2/). Works with imagen colour-2 to detect vessels

//This macro requires installation of the following plugins:
////MorpholibJ: https://imagej.net/plugins/morpholibj
////Labkit: https://imagej.net/plugins/labkit/

//Tested on Windows 64 bits Fiji ImageJ 2.16.0/1.54p; Java 1.8.0_322 [64-bit]

macro "Analyze_DABVessels_InTissue"{

	//Getting Fiji and ROI Manager ready
	
	run("ROI Manager...");
	roiManager("Reset");
	roiManager("Associate", "false");
	roiManager("Centered", "false");
	roiManager("UseNames", "true");
	run("Clear Results");
	run("Close All");
	run("Set Measurements...", "area display redirect=None decimal=3");
	run("Line Width...", "line=1");
	run("Colors...", "foreground=white background=black selection=red");
	run("Options...", "iterations=1 count=1 black do=Nothing");
	CloseWindow("Log");
	rowposition=0;
	setBatchMode(true);

	//Dialog Box
	
	Dialog.create("Analysis Parameters");
	IMGFormats=newArray(".tif", ".tiff", ".jpeg", ".png"); 
	Dialog.addChoice("Select Input image format", IMGFormats, ".tif");
	Dialog.addString("Labkit Tissue classifier Name (without file extension):", "DABVessels", 50);
	Dialog.addNumber("Vessel Min Area size", 30);
	Dialog.addNumber("DAB max threshold limit", 200);
	Dialog.addString("Name of signal to measure", "DAB");
	Dialog.addMessage("User object edition options:", 12, "#ff0056");	
	Dialog.addCheckbox("Do you want to edit detected Medulla ROI? ", true);
	Dialog.addCheckbox("Do you want to edit detected Objects ROI?", true);
	Dialog.show();
	
	//Get dialog box info
	
	ImageFormat=Dialog.getChoice();
	ClassifierName=Dialog.getString();
	VesselMinArea=Dialog.getNumber();
	DABMaxThreshold=Dialog.getNumber();
	SignalLabel=Dialog.getString();
	MedullaEdition=Dialog.getCheckbox();
	SignalEdition=Dialog.getCheckbox();
	
	
	//Print Dialog Box options
	
	print("=====================================================================================");
	print("Analysis Parameters:");
	print("--------------------");
	print("Vessel Min Area size is: "+VesselMinArea);
	print("Signal to measure is "+SignalLabel);	
	print("DAB max threshold limit "+DABMaxThreshold);	
	print("=====================================================================================");
	
	//----


	//Loop to process all files in a folder. 

	dir = getDirectory("Choose folder with files to process...");
	pathsegmenter=getDirectory("Select Labkit classifier folder...");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	output = dir+"Results_Macro_Run#_"+year+"_"+month+"_"+dayOfMonth+"_"+hour+"_"+minute+"_"+second+File.separator;
	lista = getFileList(dir);
	File.makeDirectory(output);
	print("=======================");
	print("Macro Analysis has started around "+hour+":"+minute+":"+second);
	

	for (i=0; i<lista.length; i++) {
		if(endsWith(lista[i], ImageFormat)){							
			open(dir+lista[i]);				
			myimagename=getTitle();
			print("=======================");		
			print("Beginning analysis of image "+myimagename);
			ORI=getImageID();
			getDimensions(width, height, channels, slices, frames);
			getVoxelSize(widthORI, heightORI, depthORI, unitORI);
			rename("ORI");
				
			//Create tissue ROI and compute tissue Area
				
			run("Duplicate...", "title=TISSUE");
			run("8-bit");
			print("Creating tissue ROI...");
			run("Gaussian Blur...", "sigma=4");
			setAutoThreshold("Mean");
			setOption("BlackBackground", true);
			run("Convert to Mask");
			run("Fill Holes");
			run("Area Opening", "pixel=500000");
			setThreshold(1, 255, "raw");
			run("Create Selection");
			if (selectionType!=-1){
				roiManager("Add");
				TissueROI= RenamelastindexinManager("Tissue","green",5);
				close("TISSUE");
				close("TISSUE-areaOpen");
			}else{
				close("TISSUE");
				close("TISSUE-areaOpen");
				selectImage(ORI);
				setBatchMode("show");
				waitForUser("Define tissue ROI","Use drawing tools to define a tissue ROI.\n \n Press *OK* when done to continue");
				roiManager("Add");
				TissueROI= RenamelastindexinManager("Tissue","green",5);
				selectImage(ORI);
				setBatchMode("hide");
				
			}
			selectImage(ORI);
			roiManager("Select", TissueROI);
			List.setMeasurements;
			AreaTissue=List.getValue("Area");
			run("Select None");
			roiManager("deselect");
	
			//Detect Tissue  Medulla
			
			print("Creating Cortex and Medulla ROIs...");
			selectImage(ORI);
			run("Duplicate...", "title=Cortex&Medulla");
			roiManager("select", TissueROI);
			setBackgroundColor(0, 0, 0);
			run("Clear Outside");
			run("8-bit");
			run("Gaussian Blur...", "sigma=30");
			setAutoThreshold("Huang dark");
			setOption("BlackBackground", true);
			run("Convert to Mask");
			run("Area Opening", "pixel=20000");
			setThreshold(1, 255, "raw");
			run("Create Selection");
			if (selectionType!=-1){
				roiManager("Add");
				MedullaROI= RenamelastindexinManager("Medulla","red",2);
				close("Cortex&Medulla");
				close("Cortex&Medulla-areaOpen");
			}else{
				close("Cortex&Medulla");
				close("Cortex&Medulla-areaOpen");
				selectImage(ORI);
				waitForUser("Define Medulla ROI","Use drawing tools to define a Medulla ROI.\n \n Press *OK* when done to continue");
				roiManager("Add");
				MedullaROI= RenamelastindexinManager("Medulla","red",2);
			}
			
			//User edition of Medulla ROI
			
			if(MedullaEdition==true){			
				EditROI(ORI,myimagename,MedullaROI, "Medulla");
			}
		
			//Measure Medulla Area
			
			roiManager("select", MedullaROI);
			List.setMeasurements;
			AreaMedulla=List.getValue("Area");
			run("Select None");
			roiManager("deselect");
			
			//Create Cortex ROI
			
			roiManager("Select", newArray(TissueROI,MedullaROI));
			roiManager("XOR");
			roiManager("add");
			CortexROI= RenamelastindexinManager("Cortex","yellow",1);
			
			//Measure Cortex Area
			
			roiManager("select", CortexROI);
			List.setMeasurements;
			AreaCortex=List.getValue("Area");
			run("Select None");
			roiManager("deselect");
	
			//Signal detection and quantification
			
			print("Performing Colour Deconvolution...");
			run("Subtract Background...", "rolling=200 light");
			run("Colour Deconvolution", "vectors=[H DAB]");
			close("ORI-(Colour_1)");
			close("ORI-(Colour_3)");
			close("Colour Deconvolution");
			selectWindow("ORI-(Colour_2)");
			DABimage=getImageID();
			setVoxelSize(widthORI, heightORI, depthORI, unitORI);
			run("Median...", "radius=2");
			roiManager("select", TissueROI);
			setBackgroundColor(255, 255, 255);
			run("Clear Outside");
			setThreshold(0, DABMaxThreshold, "raw");
			List.setMeasurements("limit");
			TissueDABsignal=List.getValue("Area");
			TissueDABsignalPercentage=List.getValue("%Area");
			roiManager("select", CortexROI);
			List.setMeasurements("limit");
			CortexDABsignal=List.getValue("Area");
			CortexDABsignalPercentage=List.getValue("%Area");
			roiManager("select", MedullaROI);
			List.setMeasurements("limit");
			MedullaDABsignal=List.getValue("Area");
			MedullaDABsignalPercentage=List.getValue("%Area");
			run("Create Selection");
			if(selectionType()!=1){
				roiManager("add");
				DABROI= RenamelastindexinManager("DAB","red",1);
			}
				
			//Detect vessels in DAB signal image
			
			selectImage(DABimage);
			roiManager("deselect");
			run("Select None");
			resetThreshold();
			run("Invert");
			run("Fill Holes (Binary/Gray)");
			FillHolesImageInvDAB=getImageID();
			rename("FillHolesDAB");
			close("ORI-(Colour_2)");
			selectImage(FillHolesImageInvDAB);
			
			////Remove vessels from tissue edge
			roiManager("Select", TissueROI);
			run("Enlarge...", "enlarge=-100");
			setBackgroundColor(0, 0, 0);
			run("Clear Outside");
			
			////Detection using labkit classifier
			
			print("Beginning Labkit vessels segmentation...This can take a while =)");			
			SegmentedFillHolesImageInvDAB=LabkitSegmentation (FillHolesImageInvDAB, pathsegmenter, ClassifierName);			
			selectImage(SegmentedFillHolesImageInvDAB);
			setThreshold(1, 1, "raw");
			run("Create Selection");
			roiManager("add");
			
			/////Edit selection of combined vessels
			
			selectImage(ORI);
			roiManager("show none");
			CombinedVesselsROI= RenamelastindexinManager("Combined_Vessels","blue",0);
			if(SignalEdition==true){
				EditROI(ORI,myimagename,CombinedVesselsROI, "Combined_Vessels");
			}
			
			/////Close opened images
			
			close("segmentation of FillHolesDAB");
			close("FillHolesDAB");
				
			//Create final vessel ROIs
			
			newImage("BIN", "8-bit black", width, height, 1);
			setVoxelSize(widthORI, heightORI, depthORI, unitORI);
			roiManager("select", CombinedVesselsROI);
			setForegroundColor(255, 255, 255);
			roiManager("Fill");
			setThreshold(1, 255);
			prevesselsROI=roiManager("count");
			run("Analyze Particles...", "size="+VesselMinArea+"-Infinity show=Masks add");
				
			//save vessels mask image
			
			selectWindow("Mask of BIN");
			saveAs(".tif", output+myimagename+"-Vessels-BIN");
					
			//Rename final vessels ROIs and create vessel results
			
			print("Measuring...");
			totalROIs=roiManager("count");
			vesselsROI=totalROIs-prevesselsROI;
			AreaArray=newArray(vesselsROI);
			arrayposition=0;
			run("Clear Results");
			if (isOpen("TempVesselResults")){
				Table.rename("TempVesselResults", "Results");
			}
			vesseltableposition=nResults;						
			for(roi=prevesselsROI; roi<totalROIs;roi++){
				selectImage(ORI);
				roiManager("select", roi);
				roiManager("Set Color", "blue");
				roiManager("Set Line Width", 0);
				roiManager("rename", "Vessel-"+arrayposition+1);
				List.setMeasurements;
				AreaArray[arrayposition]=List.getValue("Area");
				setResult("Vessel #", vesseltableposition, arrayposition+1);	
				setResult("Area", vesseltableposition, AreaArray[arrayposition]);	
				updateResults();
				arrayposition++;
				vesseltableposition++;
			}
			
			saveAs("Results", output+"Vessel_Area_Results.xls");
			saveAs("Results", output+"Vessel_Area_Results.txt");
											
			if (isOpen("Results")){
				Table.rename("Results", "TempVesselResults");
			}	
	
			//Signal Result table
								
			run("Clear Results");
			if (isOpen("TempResults")){
				Table.rename("TempResults", "Results");
			}
							
			setResult("Image", rowposition,myimagename);
			setResult("Area Units (^2)", rowposition, unitORI);	
			setResult("Tissue Area", rowposition, AreaTissue);
			setResult(SignalLabel+" Area", rowposition, TissueDABsignal);
			setResult("% "+SignalLabel+" in Tissue Area", rowposition, TissueDABsignalPercentage);
			setResult("Cortex Area", rowposition, AreaCortex);
			setResult(SignalLabel+" in Cortex Area", rowposition, CortexDABsignal);
			setResult("% "+SignalLabel+" in Cortex Area", rowposition,CortexDABsignalPercentage);
			setResult("Medulla Area", rowposition, AreaMedulla);
			setResult(SignalLabel+" in Medulla Area", rowposition, MedullaDABsignal);
			setResult("% "+SignalLabel+" in Medulla Area", rowposition,MedullaDABsignalPercentage);
			updateResults();
			rowposition++;
											
			saveAs("Results", output+"Results.xls");
			saveAs("Results", output+"Results.txt");
									
			if (isOpen("Results")){
				Table.rename("Results", "TempResults");
			}	
			
			//Create and save Label image
			
			selectImage(ORI);
			roiManager("show all with labels");
			run("Flatten");
			saveAs(".tif", output+myimagename+"-Labels");
			
			//Save ROI manager items
							
			roiManager("deselect");
			roiManager("save", output+myimagename+"-ROIs.zip");
			roiManager("reset");
						
			if(isOpen("Log")){
				selectWindow("Log");
				saveAs("Text", output+"Log");
			}
			
			run("Close All");
		}else{
			print("File "+lista[i]+ " format is not accepted");
		}
	}

	getDateAndTime(yearEND, monthEND, dayOfWeekEND, dayOfMonthEND, hourEND, minuteEND, secondEND, msecEND);
	print("Macro Analysis done at "+hourEND+":"+minuteEND+":"+secondEND);
	print("=================THE=END================");
	if(isOpen("Log")){
		selectWindow("Log");
		saveAs("Text", output+"Log");
	}
	
	CloseWindow("Log");
	waitForUser("Analysis done, please take a look to your results:\n  \n " + output);
}

//--------------------------------------------------------------------------------------------------------

//Macro functions:

function CloseWindow(Windownamestring){
	//Function to close a Window
	if(isOpen(Windownamestring)){
		selectWindow(Windownamestring);
		run("Close");
	}
}

function RenamelastindexinManager(ROIName,ROIcolour,ROILineWidth){
	//Function to rename last index added to ROI Manager list, returns index number
	roiManager("deselect");
	lastItemAdded=roiManager("count")-1;
	roiManager("select", lastItemAdded);
	roiManager("rename", ROIName);
	roiManager("Set Color", ROIcolour);
	roiManager("Set Line Width", ROILineWidth);
	roiManager("deselect");
	run("Select None");
	return lastItemAdded;
}

function EditROI(inputIDImg,imagenamevariable,ROIIndextoEdit, ROInametoEdit){
	//Function for user edition of a defined ROI in ROI Manager list
	selectImage(inputIDImg);
	setBatchMode("show");
	roiManager("show none");
	setTool("freehand");
	roiManager("select", ROIIndextoEdit);
	waitForUser(ROInametoEdit+" ROI Edition of file "+imagenamevariable,"Use drawing tools to edit "+ROInametoEdit+"  selection:\n\n \nFirst, make sure "+ROInametoEdit+" is active in ROIManager window, then:\n \n -> Use Alt+drawing to remove parts of a selection;\n -> Use Shift+drawing to add parts to a selection;\n -> After each modification use *Update* to save changes;\n \nPress *OK* when done to continue");				
	selectImage(inputIDImg);
	setBatchMode("hide");				
}

function LabkitSegmentation (myInputimg, pathsegmenter, ClassifierName){
	//Function to apply labkit machine learning segmentation
	selectImage(myInputimg);
	run("Select None");
	run("Duplicate...", "title=LABKIT");	
	run("Segment Image With Labkit", "input=LABKIT segmenter_file=["+pathsegmenter+ClassifierName+".classifier] use_gpu=false");
	while (isOpen("segmentation of LABKIT")!=1){wait (100);} 
	selectWindow("segmentation of LABKIT");
	run("glasbey on dark");
	myLabkitResult=getImageID();
	close("LABKIT");
	return myLabkitResult;
}






