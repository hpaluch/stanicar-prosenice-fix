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
	my ($Doc,$VozyConfig,$GvdElement,$GvdXPath) = @_;
	die "Invalid Doc argument ".(ref $Doc)
		unless ref $Doc eq 'XML::DOM::Document';
	die "Invalid VozyConfig argument".(ref $VozyConfig)
		unless ref $VozyConfig eq 'xxx';
	die "Invalid GvdElement argument".(ref $GvdElement)
		unless ref $GvdElement eq 'XML::DOM::Element';
	# verify gvd xpath
	die "Node ".dumpNodePath($GvdElement)." does not matches xpath '$GvdXPath'"
		unless $GvdElement->matches($GvdXPath);
	# TODO....


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

my $i=0;
for my $gvd ($doc->findnodes( '/root/gvd')){
	fix_missing_vozy_in_gvd(
		$doc, $VozyConfig,
		$gvd,"/root/gvd[$i]",
	);
	$i++;
}


#
# Key is "vuz" attribute name, value is XML::Dom::Attr
# see https://metacpan.org/pod/distribution/libxml-enno/lib/XML/DOM/Attr.pod
my %RequiredVuzIds;

my @nodes = $doc->findnodes( '//razeni/vuz/@typ');
foreach my $attr (@nodes){
	my $id = $attr->getValue;
	$RequiredVuzIds{$id} = $attr;
	#die  ref $attr;
	#print "typ: '$id'\n";
}

my %ProvidedVuzIds;
@nodes = $doc->findnodes( '//vozy/vuz/@id');
foreach my $attr (@nodes){
	my $id = $attr->getValue;
	$ProvidedVuzIds{$id} = 1;
	#print "typ: '$id'\n";
}

my %AddFromIniIds;

for my $id (values %{$ReplaceIds}){

	next if exists $ProvidedVuzIds{$id};
	die "Internal error: value '$id' not found in INI file"
	  unless exists $VozyConfig->{$id};
	$AddFromIniIds{$id}=1;
	print "FIXUP: Adding replacement id '$id' to AddFromIniIds\n";

}


foreach my $id (sort keys %RequiredVuzIds){
	if (!exists $ProvidedVuzIds{$id}){
		#print "WARNING: Required '$id' not in //vozy/vuz/\@id !\n";
		print Dumper(\$id);
		if (exists $VozyConfig->{$id}){
			$AddFromIniIds{$id}=1;
		} else {
			die "ID=".Dumper($id)." not found in INI nor in ReplaceIds"
		         	unless exists $ReplaceIds->{$id};
			print "*** ERROR: '$id' not found in '$vozyIniFile' !!!\n";
		}
	}
}

print "Changing not existing //vuz/\@typ to replacements...\n";
@nodes = $doc->findnodes( '//razeni/vuz/@typ');
foreach my $attr (@nodes){
	my $name = $attr->getName;
	my $id = $attr->getValue;
	if (exists $ReplaceIds->{$id}){
		my $newId = $ReplaceIds->{$id};
		print "FIXUP: Replacing attr '$name': '$id' -> '$newId'\n";
		$attr->setValue($newId);
	}
}

print "Adding missing //vozy/vuz from INI file....\n";
@nodes = $doc->findnodes( '//vozy');
for my $n (@nodes){
	print dumpNodePath($n)."\n";
}

die "Unexpected number of nodes for //vozy ".(scalar @nodes)." <> 1"
	unless scalar @nodes == 1;
my $VozyElement = $nodes[0];
print "TagName: '".$VozyElement->getTagName."'\n";

for my $id (sort keys %AddFromIniIds){
	die "Internal error: id='$id' does not exit in INI file"
		unless exists $VozyConfig->{$id};
	my $VuzElement = $doc->createElement('vuz');
	# copy ini key=value as attributes
	for my $key ( sort keys %{$VozyConfig->{$id}}){
		my $val = $VozyConfig->{$id}{$key};
		print "Adding $key=$val to //vozy/vuz/[\@id='$id']\n";
		$VuzElement->setAttribute($key,$val);
	}
	$VuzElement->setAttribute('id',$id);
	$VozyElement->appendChild($VuzElement);
}


print "Saving fixed file to '$outXml'...";
$doc->printToFile ($outXml);
print "Done.\n";

$doc->dispose;
