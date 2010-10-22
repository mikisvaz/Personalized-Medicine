#!/usr/bin/perl

#array of hashes: stores info from xml file
# 0 -> HUGOGeneSymbol
# 1 -> @GeneAliasCollection
#	1.1 -> GeneAlias
# 2 -> @SequenceIdentificationCOllection
#	2.1 -> UniProtID
# 3 -> @Sentence
#	3.1 -> @DrugData
#		3.1.1 -> DrugTerm
#		3.1.2 -> NCIDrugConceptCode
#	3.2 -> Statement
#	3.3 -> Organism (LOOK, ONLY HUMAN)


open(XML,"NCI_CancerIndex_allphases_compound.xml") or die "problem opening file\n";

#por cada GeneEntry tendremos una fila (array of hashes)
@AdH = ();
@AdA = (); #contains only alias
$hugo;
@alias;
$uniprot;
$drug;
$drugCode;
$statement;
$organism;


while ($line=<XML>){
	chomp $line;
	if ($line =~ /^<\/GeneEntry>/){
		#al final del todo metemos en el AdH
		push @AdH,{
			hugo => $hugo,
#			alias => @alias,
			uniprot => $uniprot,
			drug => $drug,
			drugCode => $drugCode,
			statement => $statement,
			organism => $organism
		};

		push @AdA,[ @alias ];
		@alias = ();				
	}else{
	 if ($line =~ /<HUGOGeneSymbol>/){
		@aux=();
		push (@aux,split('<',$line));
		$aux2 = $aux[1];
		@aux3=();
		push (@aux3,split('>',$aux2));
		$hugo =  $aux3[1];
	  }
	 if ($line =~ /<GeneAlias>/){
		@aux=();
		push (@aux,split('<',$line));
		$aux2 = $aux[1];
		@aux3=();
		push (@aux3,split('>',$aux2));
		push(@alias,$aux3[1]);
	  }
	if ($line =~ /<UniProtID>/){
		@aux=();
		push (@aux,split('<',$line));
		$aux2 = $aux[1];
		@aux3=();
		push (@aux3,split('>',$aux2));
		$uniprot = $aux3[1];		
	}
	if ($line =~ /<DrugTerm>/){
		@aux=();
		push (@aux,split('<',$line));
		$aux2 = $aux[1];
		@aux3=();
		push (@aux3,split('>',$aux2));
		$drug = $aux3[1];		
	}
	if ($line =~ /<NCIDrugConceptCode>/){
		@aux=();
		push (@aux,split('<',$line));
		$aux2 = $aux[1];
		@aux3=();
		push (@aux3,split('>',$aux2));
		$drugCode = $aux3[1];		
	}
	if ($line =~ /<Statement>/){
		@aux=();
		push (@aux,split('<',$line));
		$aux2 = $aux[1];
		@aux3=();
		push (@aux3,split('>',$aux2));
		$statement = $aux3[1];		
	}
	if ($line =~ /<Organism>/){
		@aux=();
		push (@aux,split('<',$line));
		$aux2 = $aux[1];
		@aux3=();
		push (@aux3,split('>',$aux2));
		$organism = $aux3[1];		
	}
       }#else
}#while

for $i (0 .. $#AdH){ 
	  #interested in human info (organism => human)
	  if ($AdH[$i]{organism} eq "Human"){

  	    print "$AdH[$i]{hugo}\t";
            for $j (0..$#{$AdA[$i]}){ 
		  print "$AdA[$i][$j]|"; 
	    }
	    print "\t";
	    print "$AdH[$i]{uniprot}\t";
	    print "$AdH[$i]{drug}\t";
	    print "$AdH[$i]{drugCode}\t";
	    print "$AdH[$i]{statement}\t";
	    print "$AdH[$i]{organism}\n";
	  }
}



