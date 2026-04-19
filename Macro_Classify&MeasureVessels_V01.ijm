macro "Classify&MeasureVessels"{
	
	//Getting Fiji and ROI Manager ready
	
	setBatchMode(true);
	run("Clear Results");
	run("Close All");
	run("Set Measurements...", "area display redirect=None decimal=3");
	roiManager("Reset");
	roiManager("Associate", "false");
	roiManager("Centered", "false");
	roiManager("UseNames", "true");
	run("Line Width...", "line=2");
	run("Colors...", "foreground=white background=black selection=yellow");
	
	rowposition=0;
	
	//Loop to process all files in a folder. 
	
	input=getDirectory("Choose folder with images and zip files to process");
	lista = getFileList(input);
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	outputfolder = input+"Results_Macro_Run#_"+year+"_"+month+"_"+dayOfMonth+"_"+hour+"_"+minute+"_"+second+File.separator;
	File.makeDirectory(outputfolder);
	//setBatchMode(true);
	run("Bio-Formats Macro Extensions");
	for (i=0; i<lista.length; i++) {	
		if ((endsWith(lista[i],".tif")==1)&&(endsWith(lista[i], "Vessels-BIN.tif"))){
			open(input+lista[i]);
			fullname=getTitle();
			generalname=split(fullname, "-");
			roiManager("open", input+generalname[0]+"-ROIs.zip");
	
			//Get index position of Medulla ROI
			
			MedullaIndex=FindMyROIIndex("Medulla");
			
			//Get index position of Cortex ROI
			
			CortexIndex=FindMyROIIndex("Cortex");
			
			//Get index position of first ROI called Vessel
			
			totalROIs=roiManager("count");
			checkpoint=0;
			roi=0;
			
			do{
				roiManager("select", roi);
				myroiname=Roi.getName;
					if(startsWith(myroiname,"Vessel-")==true){
						checkpoint=1;
						vesselfirstIndex=roi;
					}else{
						roi++;
					}
			}while((checkpoint==0)&& (roi<totalROIs));
			
			//Open binary image with vessels
			VesselBIN=getImageID();
			run("RGB Color");
			Stack.getDimensions(widthBIN, heightBIN, channelsBIN, slicesBIN, framesBIN);
			getVoxelSize(widthVX, heightVX, depthVX, unitVX);
			//Create new binary image for Medulla and Cortex rois
			newImage("Labels", "8-bit black", widthBIN, heightBIN, 1);
			LabelImage=getImageID();
			setVoxelSize(widthVX, heightVX, depthVX, unitVX);	
			//Paint Medulla and Cortex ROI and assign each area a number
			roiManager("select", MedullaIndex);
			run("Add...", "value=1");
			roiManager("select", CortexIndex);
			run("Add...", "value=2");
			
			//Classify vessels based on their value (1 to Medulla, 2 to Cortex)
			vesselsROI=totalROIs-vesselfirstIndex;
			ROInames=newArray(vesselsROI);
			MeanValue=newArray(vesselsROI);
			AreaValue=newArray(vesselsROI);
			AreaValueInMedulla=newArray(vesselsROI);
			VesselInMedulla=newArray(vesselsROI);
			VesselInMedullaCount=0;
			VesselInCortex=newArray(vesselsROI);
			AreaValueInCortex=newArray(vesselsROI);
			VesselInCortexCount=0;
			AreaValueInBoth=newArray(vesselsROI);
			VesselInBoth=newArray(vesselsROI);
			VesselInBothCount=0;
			
			arrayposition=0;
			for(roi=vesselfirstIndex;roi<totalROIs;roi++){
				selectImage(LabelImage);
				roiManager("select", roi);
				ROInames[arrayposition]=Roi.getName;
				List.setMeasurements;
				AreaValue[arrayposition]=List.getValue("Area");
				MeanValue[arrayposition]=List.getValue("Mean");
				if(MeanValue[arrayposition]==1){
					VesselInMedullaCount++;
					VesselInMedulla[arrayposition]="Yes";
					AreaValueInMedulla[arrayposition]=AreaValue[arrayposition];
					selectImage(VesselBIN);
					roiManager("select", roi);
					setForegroundColor(255, 0, 0);
					roiManager("fill");
				}else if (MeanValue[arrayposition]==2){
					VesselInCortexCount++;
					VesselInCortex[arrayposition]="Yes";
					AreaValueInCortex[arrayposition]=AreaValue[arrayposition];
					selectImage(VesselBIN);
					roiManager("select", roi);
					setForegroundColor(0, 255, 0);
					roiManager("fill");
				}else if(MeanValue[arrayposition]!=2 || MeanValue[arrayposition]!=1){
					VesselInBothCount++;
					VesselInBoth[arrayposition]="Yes";
					AreaValueInBoth[arrayposition]=AreaValue[arrayposition];
					selectImage(VesselBIN);
					roiManager("select", roi);
					setForegroundColor(255, 255, 0);
					roiManager("fill");
				}
				arrayposition++;	
			}
			
			close("Labels");
						
			//Remove zero values from arrays before computing statistics
			
			AreaValueInMedulla=Array.deleteValue(AreaValueInMedulla, 0);
			AreaValueInCortex=Array.deleteValue(AreaValueInCortex, 0);
			AreaValueInBoth=Array.deleteValue(AreaValueInBoth, 0);
			//Get array statistics
			Array.getStatistics(AreaValueInMedulla, minInMedulla, maxInMedulla, meanInMedulla, stdDevInMedulla);
			Array.getStatistics(AreaValueInCortex, minInCortex, maxInCortex, meanInCortex, stdDevInCortex);
			Array.getStatistics(AreaValueInBoth, minInBoth, maxInBoth, meanInBoth, stdDevInBoth);
			//Create and save table with array data
			Array.show("ROI_DATA_Image_"+fullname, ROInames, AreaValue, VesselInMedulla, VesselInCortex,VesselInBoth);
			selectWindow("ROI_DATA_Image_"+fullname);
			saveAs("Results", outputfolder+"ROI_DATA_Image_"+fullname+".xls");
			selectWindow("ROI_DATA_Image_"+fullname+".xls");
			run("Close");
			
			//Create results table
								
			run("Clear Results");
			if (isOpen("TempResults")){
				Table.rename("TempResults", "Results");
			}
		
			setResult("Image", rowposition,fullname);
			setResult("Area Units (^2)", rowposition, unitVX);	
			setResult("Vessels in Medulla count", rowposition,VesselInMedullaCount);
			setResult("Mean Area of Vessels in Medulla", rowposition,meanInMedulla);
			setResult("SD of Mean Area of Vessels in Medulla", rowposition,stdDevInMedulla);
			setResult("Vessels in Cortex count", rowposition,VesselInCortexCount);	
			setResult("Mean Area of Vessels in Cortex", rowposition,meanInCortex);
			setResult("SD of Mean Area of Vessels in Cortex", rowposition,stdDevInCortex);
			setResult("Vessels in both Medulla-Cortex count", rowposition,VesselInBothCount);
			setResult("Mean Area of Vessels in Both", rowposition,meanInBoth);
			setResult("SD of Mean Area of Vessels in Both", rowposition,stdDevInBoth);
			rowposition++;
					
			selectWindow("Results");
			saveAs("Results", outputfolder+"Results.xls");
			saveAs("Text", outputfolder+"Results.txt");
									
			if (isOpen("Results")){
				Table.rename("Results", "TempResults");
			
			}
			selectImage(VesselBIN);
			saveAs("tif", outputfolder+fullname+"_Label-Image");
			run("Close All");
			roiManager("reset");
		}
	}
	waitForUser("Analysis done, take a look to your results saved here:\n "+outputfolder);
}

//Macro functions:
//===============

//Find index of defined ROI name

function FindMyROIIndex(parameter){	
	totalROIs=roiManager("count");
	checkpoint=0;
	roi=0;
	
	do{
		roiManager("select", roi);
		myroiname=Roi.getName;
		if(myroiname==parameter){
			checkpoint=1;
			MyIndex=roi;
		}else{
				roi++;
				MyIndex=0;
		}
	}while((checkpoint==0)&& (roi<totalROIs));
	return MyIndex;
}
