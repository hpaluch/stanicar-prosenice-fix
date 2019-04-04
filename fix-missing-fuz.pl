#!/usr/bin/perl -w

# Tested under Win10/amd64 + strawberry-perl-5.26.2.1-64bit.msi 
# Install following deps in Strawberry perl:
#    cd /d "C:\Strawberry\perl\bin"
#    cpanm XML::DOM
#    cpanm Config::Tiny
#    # "-n" run without tests (are failing)
#    cpanm XML::DOM::XPath -n

use strict;
use warnings;

use Data::Dumper;
use XML::DOM;
use XML::DOM::XPath;
use Config::Tiny;

my $vozyIniFile = "vozy.ini";
my $inXml = "prosenice_1-50.xml";
my $outXml = "prosenice_1-59.xml";
my $outXmlTemplate = "prosenice_1-59-template.xml";

# These IDs does not exit in Stag so we must replace them...
my $ReplaceIds = {
  "182_\x{10c}D" => "182",
  "363_CD Cargo" => "363",
  'Bee240(61)_CD' => 'Bee240_CD',
};


sub dumpNodePath {
	my ($Node) = @_;

	die "Invalid param type ".ref $Node
		unless ref $Node eq 'XML::DOM::Element';

	my $Parent = $Node;
	my @Path;
	while( defined $Parent ){
		last if ref $Parent eq 'XML::DOM::Document';
		die "Inavlid parent type ".(ref $Parent)
			unless ref $Parent eq 'XML::DOM::Element';
		#print "Type: ".(ref $Parent)." name: ".$Parent->getNodeName."\n";
		push @Path, $Parent->getNodeName;
		$Parent = $Parent->getParent;
	}
	@Path = reverse @Path;
	return "/".join('/',@Path);
}

sub fix_missing_vozy_in_gvd {
	my ($Doc,$VozyConfig,$Gvd,$GvdXPath) = @_;
	die "Invalid Doc argument ".(ref $Doc)
		unless ref $Doc eq 'XML::DOM::Document';
	die "Invalid VozyConfig argument '".(ref $VozyConfig)."'"
		unless ref $VozyConfig eq 'Config::Tiny';
	die "Invalid Gvd argument".(ref $Gvd)
		unless ref $Gvd eq 'XML::DOM::Element';
	# verify gvd xpath
	# DOES NOT WORK
	#die "Node ".dumpNodePath($Gvd)." does not matches xpath '$GvdXPath'"
	#	unless $Gvd->matches($GvdXPath);
	#
	
	# Manual test...
	my @Nodes = $Doc->findnodes($GvdXPath);
	die "Unexpected number of nodes ".(scalar @Nodes)." <> 1"
		unless scalar @Nodes == 1;
	my $Gvd2 = $Nodes[0];
	die "Gvd Element and GvdXPath mismatch"
		unless "$Gvd" eq "$Gvd2";

	#
	# Key is "vuz" attribute name, value is XML::Dom::Attr
	# see https://metacpan.org/pod/distribution/libxml-enno/lib/XML/DOM/Attr.pod
	my %RequiredVuzIds;

	# WARNING! $Gvd->findnodes() works wrong way (like $Doc->findnodes())!!!
	@Nodes = $Doc->findnodes( $GvdXPath.'//razeni/vuz/@typ');
	print "Found ".(scalar @Nodes)." of $GvdXPath//razeni/vuz/\@typ\n";
	foreach my $Attr (@Nodes){
		my $ID = $Attr->getValue;
		$RequiredVuzIds{$ID} = $Attr;
		#die  ref $Attr;
		#print "typ: '$ID'\n";
	}

	my %ProvidedVuzIds;
	@Nodes = $Doc->findnodes( $GvdXPath.'//vozy/vuz/@id');
	foreach my $Attr (@Nodes){
		my $ID = $Attr->getValue;
		$ProvidedVuzIds{$ID} = 1;
		#print "typ: '$ID'\n";
	}

	my %AddFromIniIds;

	for my $ID (values %{$ReplaceIds}){
		next if exists $ProvidedVuzIds{$ID};
		die "Internal error: value '$ID' not found in INI file"
		  unless exists $VozyConfig->{$ID};
		$AddFromIniIds{$ID}=1;
		print "FIXUP: Adding replacement id '$ID' to AddFromIniIds\n";
	}

	foreach my $ID (sort keys %RequiredVuzIds){
		if (!exists $ProvidedVuzIds{$ID}){
			#print "WARNING: Required '$ID' not in //vozy/vuz/\@id !\n";
			print Dumper(\$ID);
			if (exists $VozyConfig->{$ID}){
				$AddFromIniIds{$ID}=1;
			} else {
				die "ID=".Dumper($ID)." not found in INI nor in ReplaceIds"
					unless exists $ReplaceIds->{$ID};
				print "*** ERROR: '$ID' not found in '$vozyIniFile' !!!\n";
			}
		}
	}

	print "Changing not existing //vuz/\@typ to replacements...\n";
	@Nodes = $Doc->findnodes( $GvdXPath.'//razeni/vuz/@typ');
	foreach my $Attr (@Nodes){
		my $Name = $Attr->getName;
		my $ID = $Attr->getValue;
		if (exists $ReplaceIds->{$ID}){
			my $NewId = $ReplaceIds->{$ID};
			print "FIXUP: Replacing attr '$Name': '$ID' -> '$NewId'\n";
			$Attr->setValue($NewId);
		}
	}

	print "Adding missing //vozy/vuz from INI file....\n";
	@Nodes = $Doc->findnodes( $GvdXPath.'//vozy');
	for my $N (@Nodes){
		print dumpNodePath($N)."\n";
	}

	die "Unexpected number of nodes for //vozy ".(scalar @Nodes)." <> 1"
		unless scalar @Nodes == 1;
	my $VozyElement = $Nodes[0];
	print "TagName: '".$VozyElement->getTagName."'\n";

	for my $ID (sort keys %AddFromIniIds){
		die "Internal error: id='$ID' does not exit in INI file"
			unless exists $VozyConfig->{$ID};
		my $NewLine = $Doc->createTextNode("\n    ");
		$VozyElement->appendChild($NewLine);
		my $VuzElement = $Doc->createElement('vuz');
		# copy ini Key=Val as attributes
		for my $Key ( sort keys %{$VozyConfig->{$ID}}){
			my $Val = $VozyConfig->{$ID}{$Key};
			print "Adding $Key=$Val to //vozy/vuz/[\@id='$ID']\n";
			$VuzElement->setAttribute($Key,$Val);
		}
		$VuzElement->setAttribute('id',$ID);
		$VozyElement->appendChild($VuzElement);
	}
	my $NewLine = $Doc->createTextNode("\n    ");
	$VozyElement->appendChild($NewLine);
}


my $VozyConfig = Config::Tiny->read( $vozyIniFile, 'encoding(windows-1250)');
#die Dumper($VozyConfig);

# Sanity check - verify that ReplaceIds values really exists in INI file
for my $id (values %{$ReplaceIds}){

	die "Internal error: value '$id' not found in '$vozyIniFile' file"
	  unless exists $VozyConfig->{$id};
}


my $parser = new XML::DOM::Parser;
print "Parsing '$inXml'...";
my $doc = $parser->parsefile ($inXml);
print "Done\n";

print "Saving template to file to '$outXmlTemplate'...";
$doc->printToFile ($outXmlTemplate);
print "Done.\n";

my $i=1;
for my $gvd ($doc->findnodes( '/root/gvd')){
	fix_missing_vozy_in_gvd(
		$doc, $VozyConfig,
		$gvd,"/root/gvd[$i]",
	);
	$i++;
}



print "Saving fixed file to '$outXml'...";
$doc->printToFile ($outXml);
print "Done.\n";

$doc->dispose;
