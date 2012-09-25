import eyeD3
import os


class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    def disable(self):
        self.HEADER = ''
        self.OKBLUE = ''
        self.OKGREEN = ''
        self.WARNING = ''
        self.FAIL = ''
        self.ENDC = ''

def find_readable_file(directory):
 os.chdir(mp3_root+directory)
 for files in os.listdir("."):
    if files.endswith(".m4a") or files.endswith(".mp3") or files.endswith(".ogg"):
	fileFound=files
	return fileFound

def create_new_tagdir(mp3_dir):
 tag = eyeD3.Tag() 
 tag.link(find_readable_file(mp3_dir))
 tag_str=str(tag.getArtist()) + ' - ' + str(tag.getYear()) + ' - ' + str(tag.getAlbum()) 
 print bcolors.WARNING + tag_str + bcolors.ENDC
 print "\n IDE TAGS"
 print tag.getArtist()
 print tag.getYear()
 print tag.getAlbum()
 return tag_str
	
def album_tag_exists(mp3_dir):
 try:
  tag = eyeD3.Tag() 
  tag.link(find_readable_file(mp3_dir))
  try: Artist=tag.getArtist()
  except Artist="None"
  	print mp3_dir + ' NOK'

def recursive_dirs(directory):
	 for mp3_dir in os.listdir(directory):
		if os.path.isdir(os.path.join(directory, mp3_dir)):
			os.chdir(mp3_root+mp3_dir)
			#print mp3_dir
			album_tag_exists(mp3_dir)
#
##MAIN-------------------------------
mp3_root='/home/ferran/mp3/'
#mp3_dir='/home/ferran/mp3/Disturbed - Indestructible - 2008/'

recursive_dirs(mp3_root)
